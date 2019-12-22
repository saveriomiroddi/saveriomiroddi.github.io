---
layout: post
title: Introduction to theory and practice of improving MySQL write speed, with a focus on the redo log
tags: [databases,mysql]
---

Since I work a lot on data, in order to speed up my tasks, I've been keeping my MySQL data files entirely in RAM since long ago.

I was wondering if I could make this setup simpler/more accessible, so I investigated what's the minimal change I can do to keep the system speedy.

A few interesting concepts came out, so I've decided to write a post. Since there's a large amount of information on this subject, I'm focusing on the approach, rather than on the data (of course, I'm publishing the data as well).

All in all, this post will be an introduction to the InnoDB write subsystem, and some theory and practice of improving the MySQL write speed.

TL;DR: put the log files on the fastest possible storage device, according to the durability requirements of the environment.

XXX: readers jump to YYY sections

Contents:

- [Introduction](#introduction)
- [A very high-level description of the InnoDB write-related components](#a-very-high-level-description-of-the-innodb-write-related-components)
  - [Dirty pages flushing](#dirty-pages-flushing)
  - [The redo log](#the-redo-log)
    - [The redo log: a scenario](#the-redo-log-a-scenario)
  - [Problems associated with this architecture](#problems-associated-with-this-architecture)
    - [Redo log: lower size bound](#redo-log-lower-size-bound)
    - [Redo log: uppser size bound](#redo-log-uppser-size-bound)
    - [InnoDB I/O activity](#innodb-io-activity)

- [Benchmarks](#benchmarks)
  - [Setup](#setup)
  - [Results](#results)
    - [rkldstruk (3 runs)](#rkldstruk-3-runs)
    - [data snapshot load (1 run)](#data-snapshot-load-1-run)
    - [rspec spec/models/master_allocation_spec.rb (2 runs)](#rspec-specmodelsmaster_allocation_specrb-2-runs)
    - [sysbench 1.0.18](#sysbench-1018)

- [Analysis](#analysis)
  - [Analysis script](#analysis-script)

- [Bibliography](#bibliography)

## Introduction

XXX

XXX: MySQL version referenced.

XXX: Style

XXX: terminology: server/service/system

XXX: structure of the article

## A very high-level description of the InnoDB write-related components

Database systems have many complexities; in particular, in relational database systems, a part of them is due to supporting the ACID properties.

In "ACID", the `D` stays for Durability, which:

> guarantees that once a transaction has been committed, it will remain committed even in the case of a system failure.

Honoring this guarantee has a significant impact on write performance.

### Dirty pages flushing

Like many other storage systems, data in the databases is stored in form of pages, both in memory and on disk.

When a change is performed, in-memory pages involved are marked as "dirty". The process of storing the changes on disk is called "flushing".

Let's assume a naïve system, where flushing happens immediately. How would that work? Well, while this may work on a light write load, in case of a spike, the database would grind to a halt, as it'd be busy writing to the disk.

A significant factor in the write slowness is that writing pages is random I/O: even if a set of changes are applied to the same data structure (e.g. table, or at a lower level, tree), the pages are generally scattered (XXX¹: specify at disk level; there is also tree fragmentation).

In MySQL, flushing is therefore an asynchronous job, performed by the page cleaner threads (²: https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-flushing.html); this allows the system to flush pages in periods of lower activity, so that it doesn't impact the server performance.

Note that some special-purpose database systems actually use data structures ([LSM trees](https://en.wikipedia.org/wiki/Log-structured_merge-tree)) that optimize writes, by performing them only on an append (therefore, sequential) basis. MySQL is a general purpose RDBMS, and it uses (the common) B+trees, instead.

### The redo log

The page clear threads solve the performance problem, but introduce another: they work against the durability property.

Since they introduce a delay before a given page is flushed, if the system fails in the meanwhile, the change is lost. So we're back from scratch.

What's the solution to this? Here it comes the "redo log".

The idea is relatively simple: the system still defers the flushing, however, it additionally stores the changes in a log, in a sequential fashion. The log needs to be written immediately (XXX³: depending on the flush setting), however, since the writes are sequential, the latency is significantly lower (XXX⁴: SSDs).

Obviously, this implies that the writes are amplified, however, it's important to understand that even a busy server is not 100% busy all the time, so the writes can be spread during times of lighter load.

With this strategy, we can therefore satisfy the durability requirement, while limiting the latency problem.

Under regular conditions the system periodically flushes the dirty pages; at intervals, the so-called [Redo log checkpointer thread](https://dev.mysql.com/doc/dev/mysql-server/8.0.11/PAGE_INNODB_REDO_LOG_THREADS.html#sect_redo_log_checkpointer)) takes a look at the list of pages that are scheduled for flushing, and moves accordingly the so-called "checkpoint" - the point in the redo log before which the corresponding dirty pages have already been performed.

If the system crashes, on restart, it just has a look at where the checkpoint is, and replay all the writes after, so that it ensures that the data is fully consistent before it's made available.

This architecture is called [Write-ahead logging](https://en.wikipedia.org/wiki/Write-ahead_logging).

#### The redo log: a scenario

To better understand this, let's go through a scenario.

1. suppose that page 64 is dirty. Current state: flush list=[64]; redo log=[64]

2. a write is performed. Current state: flush list=[64, 38911, 64738], redo log=[64, 38911, 63738]

3. the page 38911 is flushed (flushing doesn't need to be performed in order XXX: neigboring pages). Current state: flush_list=[64, 64738], redo log=[64, 38911, 63738]

Now, the checkpointer thread goes through the flush list. Can it advance the checkpoint?

No! If it advanced it to 63738, and immediately after, there was a system crash, the change corresponding to page 64 would be lost! Let's follow up.

4. the page 64 is flushed. Current state: flush_list=[64738], redo log=[64, 38911, 63738]

The checkpointer thread goes through the flush list. Can it advance the checkpoint now? Yes:

5. the checkpoint is advanced. Current state: flush_list=[64738], redo log=[63738]

Now suppose there is a crash. The flush list is lost, along with the dirty page 64738! But this is not a problem; on startup, the server goes through the redo log, replays it, and the change corresponding to the page 64738 is written to the data files.

### Problems associated with this architecture

There are a few problems associated with this architecture; let's review them.

#### Redo log: lower size bound

Once the checkpoint has advanced, we don't need anymore the previous data. Since on filesystems, files can't be truncated *before* a certain point, the simple solution adopted is to write to the redo log in a circular fashion.

However, writing in circle implies that after reaching a certain file size, the writes will move to the beginning of the file; therefore, the redo log file(s) needs to be fixed. In turn, this implies that at any point in time, there is a fixed amount of space available. What if it gets filled?

That's B-A-D! This situation causes a so-called sharp checkpoint: InnoDB will essentially stop the world, and frantically flush the dirty pages. This actually happens before the space is exhausted (\~90% of the total log size).

The edge-scenario flushing mechanism has actually two stages; before reaching a sharp checkpoint, InnoDB starts flushing in an asynchronous fashion, therefore, without stopping the world, at \~75% of the total log size. This is still bad, and should be avoided at all costs, as the throughput will fall drastically.

From this comes the first consideration: make the log files big enough (via [`innodb_log_file_size`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_log_file_size) and [`innodb_log_files_in_group`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_log_files_in_group)).

As a rule of thumb, one can compute how much, in average, is written in one hour (via the status variable [Innodb_os_log_written](https://dev.mysql.com/doc/refman/8.0/en/server-status-variables.html#statvar_Innodb_os_log_written)), and set the total logs size to this amount; this is of course an extremely generic advice, and everybody should adjust it according to their requirements.

The second consideration is: why, then, not making the logs file size virtually infinite?

#### Redo log: uppser size bound

Let's suppose we set the logs file size infinite. The logs won't get in the way. After an year, the server crashes.

Ooops.

What happens now? The server will need to replay the redo log. And in this case, it this will take a **very** long time. A very generic estimation from the Percona guys is [5 minutes per 1 GB of log](https://www.percona.com/blog/2017/10/18/chose-mysql-innodb_log_file_size).

So in addition to considering the lower bound of the log size, the db admin(s) will need to consider the upper bound.

#### InnoDB I/O activity

Up to this point, we've assumed that InnoDB will quietly flush the buffer during quite times. Does it?

Not really. We have a few factors to consider here:

- the limit to how much flushing should InnoDB perform in a given unit of time ([`innodb_io_capacity`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_io_capacity))
- the limit to how many dirty pages, in percentage, InnoDB should allow at any time ([`innodb_max_dirty_pages_pct`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_max_dirty_pages_pct))
- the strategy the InnoDB uses to allocate the write budget over time ([`innodb_adaptive_flushing`](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html#sysvar_innodb_adaptive_flushing))

Those are further complicated by the so-called low watermark variables, and a few extra variables.

The application of the above is highly system and workfload dependent.

There is a [Percona post](https://www.percona.com/blog/2011/01/03/mysql-5-5-8-in-search-of-stability) that, although uses a very old MySQL version, shows a tentative approach to reach the ideal compromise between the main variables.

The general idea is that we want to nudge InnoDB to flush dirty pages as continuously as possible, so that it doesn't reach a point where frantic flushing happens (think about `innodb_max_dirty_pages_pct`), but we don't want it to write too much (think about `innodb_io_capacity`), so that it doesn't hinder log writing.

The [MySQL InnoDB buffer pool flushing](https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-flushing.html) contains all the knobs that can be turned to tweak this area.

## Benchmarks

XXX:

- note COW systems don't need doublewrite
- perform tests and study involved variables
  - run test sample with i/o bottleneck, and find interesting variables
  - review if meaningful to print diagram (dirty pages %, checkpoint age)

### Setup

#### MySQL settings

The base setup is a pretty standard configuration for production, with minor changes:

setting                         | value                              | comment
------------------------------- | ---------------------------------- | ----------------------------------------------------------------------------------
(data files)                    | (all on a 1.1 GB ext4 partition)   |
skip-log-bin                    | TRUE                               | The binary log is essential in production, but it's not the focus of this article.
innodb_file_per_table           | TRUE (default)                     |
innodb_flush_log_at_trx_commit  | 0 (default)                        |
innodb_doublewrite              | TRUE (default)                     |
innodb_buffer_pool_size         | 3072M                              | Small for production standards, but enough for this article's scope.
innodb_io_capacity              | 200 (default)                      |
innodb_log_file_size            | 48M (default)                      |
innodb_log_files_in_group       | 2 (default)                        |
innodb_flush_method             | O_DIRECT                           | Standard tweak.
innodb_max_dirty_pages_pct      | 75 (default)                       |

As introduced above, there are other more specialized settings, but for simplicity, we're going to ignore them.

It's worth nothing that doublewrite is [not needed on ZFS](https://web.archive.org/web/20071026144340/http://dev.mysql.com/tech-resources/articles/mysql-zfs.html#The_InnoDB_Doublewrite_buffer_and_transactional_storage), and likely, on COW systems in general (like BTRFS, although I don't recommend it for production environments).

#### System setup

- Disk: Samsung 860 Pro 1 TB (SSD)
- CPU: AMD Ryzen 7 3800X
- RAM: 32 GiB
- MySQL: 8.0.18
- O/S: Ubuntu 18.04 (derivative)

#### Benchmarks

There are four benchmarks in total.

The reference is [Sysbench 1.0.18](https://github.com/akopytov/sysbench), using the `oltp_read_write.lua` script, tweaked in order to simulate a write-heavy system (XXX: https://severalnines.com/database-blog/how-benchmark-performance-mysql-mariadb-using-sysbench).

However, I wanted measurements of real-world tasks, therefore, I've additionally picked three operations I perform on a daily basis:

- dropping the existing schemas, and reload the empty schema (and triggers) of Ticketsolve ([my company's application](https://www.ticketsolve.com)), a Rails application composed of around 100 tables and 60 triggers;
- restoring a table of non-trivial size (around 2.3 GiB data and 1 GiB indexes);
- executing a Ticketsolve's test suite.

##### Setting up and running sysbench

The Sysbench benchmark is set up and executed with the following parameters/script:

```sh
git clone https://github.com/akopytov/sysbench.git
cd sysbench
git checkout v1.0.18 # 1327e79 # v1.0.18 doesn't support warmup
./autogen.sh
./configure
make -j
```

```sh
# Source: https://severalnines.com/database-blog/how-benchmark-performance-mysql-mariadb-using-sysbench

# XXX: mention percona tpc-c
# git clone https://github.com/Percona-Lab/sysbench-tpcc

# pkill mysqld
# # modify the mysql configuration...
# mysqld &
# 3134

# export PATH="$PATH:$PWD/src"
# cd ..
# git clone https://github.com/Percona-Lab/sysbench-tpcc
# cd sysbench-tpcc

background_services stop

mystop

chown -R saverio: /media/saverio/temp_*
mkdir -p /dev/shm/mysql_logs /media/saverio/temp_a/mysql_data /media/saverio/temp_a/mysql_logs /media/saverio/temp_b/mysql_logs

cd ~/code/sysbench

# sda4/sdb2
#
# zpool destroy tank

# zpool create -o ashift=12 mytest /dev/sda4

# zfs create -o atime=off -o recordsize=8k   -o logbias=throughput                     -o mountpoint=/media/saverio/temp_a/mysql_logs mytest/mysql_log
# zfs create -o atime=off -o recordsize=128k -o logbias=throughput -o compression=gzip -o mountpoint=/media/saverio/temp_a/mysql_logs mytest/mysql_log

# zfs create -o atime=off -o recordsize=8k -o logbias=throughput -o primarycache=metadata -o mountpoint=/media/saverio/temp_a/mysql_data mytest/mysql_data

# chown -R saverio: /media/saverio/temp_*

# modify .cnf
ls -l "$HOME/code/myblog/__tmp_mysqldata__"

mystop; rm -rf /dev/shm/mysql_logs/* /media/saverio/temp_*/mysql_*/*; mystart
sudo fstrim --all

STATS_DIR="$HOME/code/myblog/__tmp_mysqldata__/00_unconfigured"
THREADS=16
RUN_TIME=900
TABLES=20
TABLE_SIZE=50000 # orig: 10000000
# --warmup-time="$WARMUP_TIME" XXX: NOT USED

PREPARE_OPTIONS=(
  --mysql-socket=/tmp/mysql.sock --mysql-user=root
  --threads="$THREADS" --tables="$TABLES" --table-size="$TABLE_SIZE"
)
RUN_OPTIONS=(
  --mysql-socket=/tmp/mysql.sock --mysql-user=root
  --threads="$THREADS" --tables="$TABLES" --table-size="$TABLE_SIZE"
  --time="$RUN_TIME" --report-interval=1
  --delete_inserts=10 --index_updates=10 --non_index_updates=10
)

mysql -e "CREATE SCHEMA sbtest"

src/sysbench src/lua/oltp_read_write.lua "${PREPARE_OPTIONS[@]}" prepare

rm -rf "$STATS_DIR"

src/sysbench src/lua/oltp_read_write.lua "${RUN_OPTIONS[@]}" run | mysql_collect_stats -r " tps: (\d+\.\d+) " -v Sysbench_tps "$STATS_DIR"
mystop

mysql_plot_diagrams -s 600                                                                  "$STATS_DIR"
mysql_plot_diagrams -s 600 -o Checkpoint_age,Sysbench_tps,Innodb_buffer_pool_pages_dirty -1 "$STATS_DIR"

# Adhoc

mysql_plot_diagrams -s 600 -o Checkpoint_age                 "$HOME/Desktop/mysql_benchmark"/*
mysql_plot_diagrams -s 600 -o Sysbench_tps                   "$HOME/Desktop/mysql_benchmark"/*
mysql_plot_diagrams -s 600 -o Innodb_buffer_pool_pages_dirty "$HOME/Desktop/mysql_benchmark"/*

mysql_plot_diagrams -s 600 -o Checkpoint_age,Sysbench_tps,Innodb_buffer_pool_pages_dirty -1 "$HOME/Desktop/mysql_benchmark/02_logs_256" 
```

#### ZFS (temp)

Taken from ArchWiki and Percona "hands on look at zfs with mysql"

- https://wiki.archlinux.org/index.php/ZFS
- https://www.percona.com/blog/2017/12/07/hands-look-zfs-with-mysql

### Philosophy

XXX: microbenchmark notes

### Results

#### rkldstruk (3 runs)

datadir | innodb_data_home_dir | innodb_log_group_home_dir |
------- | -------------------- | ------------------------- |
        |                      |                           | 15.3
   ✓    |                      |                           | 13.8
        |                      |              ✓            | 1.061
   ✓    |                      |              ✓            | 0.99
   ✓    |            ✓         |              ✓            | 0.85

#### data snapshot load (1 run)

times: table data/indexes build

datadir | innodb_data_home_dir | innodb_log_group_home_dir |    time
------- | -------------------- | ------------------------- | ----------
        |                      |                           | 2:31 + 52"
   ✓    |                      |              ✓            | 2:14 + 51"
        |                      |              ✓            | 2:14 + 50"
   ✓    |            ✓         |              ✓            | 2:01 + 45"

#### rspec spec/models/master_allocation_spec.rb (2 runs)

datadir | innodb_data_home_dir | innodb_log_group_home_dir |    time
------- | -------------------- | ------------------------- | ----------
        |                      |                           | 32.9"
   ✓    |            ✓         |              ✓            | 32.6"

## Analysis

XXX: approach

## Bibliography

XXX: re-read/cleanup/comment/reorganize this section

- https://www.fromdual.com/node/1291
  - log data and checkpoint age can be found in the `LOG` section in `SHOW ENGINE INNODB STATUS`
- https://www.cnblogs.com/xiaotengyi/p/4149776.html
  - Innodb_os_log_written != LSN increment (log seq number)
- https://www.percona.com/blog/2011/04/04/innodb-flushing-theory-and-solutions
  - checkpoint: oldest non-flushed modified page
  - async/sync points (innodb starts flushing without/with blocking)
- https://www.percona.com/blog/2017/10/18/chose-mysql-innodb_log_file_size/
- https://www.percona.com/blog/2011/03/31/innodb-flushing-a-lot-of-memory-and-slow-disk
- https://www.percona.com/blog/2011/09/18/disaster-mysql-5-5-flushing
  - `Pending writes: LRU 0, flush list 0, single page 0`: too much I/O
  - checkpoint age = `Log flushed up to` - `Last checkpoint at`
  - sync point is usually 75% of log size, so if checkpoint age > sync point, system is screwed
  - in case of sync issues, first try to decrease `innodb_max_dirty_pages_pct`
- https://www.percona.com/blog/2011/01/03/mysql-5-5-8-in-search-of-stability
  - diagrams
    - throughput (target: be stable)
    - dirty pages pct (`(100*Innodb_buffer_pool_pages_dirty)/(1+Innodb_buffer_pool_pages_data+Innodb_buffer_pool_pages_free)`) and
      checkpoint age (`Log sequence number - Last checkpoint at`)
    - plays with:
      - innodb_max_dirty_pages_pct
      - innodb_io_capacity
      - innodb_doublewrite
      - log file size
      - others: (innodb_flush_neighbor_pages, ...)
- https://www.percona.com/blog/2016/05/31/what-is-a-big-innodb_log_file_size
- https://www.percona.com/blog/2008/11/21/how-to-calculate-a-good-innodb-log-file-size
  - compute `Log sequence number` increase over an hour, and make the log file size so
- source code:
  - `ag --ignore mysql-test --ignore share innodb_max_dirty_pages_pct` -> found it goes into `srv_max_buf_pool_modified_pct`
  - `ag srv_max_buf_pool_modified_pct storage` -> found interesting `buf_get_modified_ratio_pct()`
  - -> `100 * flush_list_len) / (1 + lru_len + free_len`
  - vars
    - `buf_pool->LRU`
    - `buf_pool->free`
    - `buf_pool->flush_list`
  - `ag innodb_buffer_pool_pages_dirty storage` # couldn't find at first, so first tried to strip `Innodb_`, then tried lower case
    - `export_vars.innodb_buffer_pool_pages_dirty = flush_list_len;`
    - `export_vars.innodb_buffer_pool_pages_data = LRU_len;`
    - `export_vars.innodb_buffer_pool_pages_free = free_len;`
- https://www.fromdual.com/innodb-variables-and-status-explained
- https://dev.mysql.com/doc/dev/mysql-server/8.0.12/PAGE_INNODB_REDO_LOG.html
- https://dev.mysql.com/doc/refman/8.0/en/innodb-checkpoints.html
- https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-flushing.html
  - `innodb_max_dirty_pages_pct_lwm` -> initiates async
  - `innodb_flush_neighbors` -> disable on SSD (default on 8.0.3+)
  - sharp (sync) checkpoints can happen on low log space, even if `innodb_max_dirty_pages_pct` is not reached
- https://www.percona.com/blog/2012/02/17/the-relationship-between-innodb-log-checkpointing-and-dirty-buffer-pool-pages
  - `Database pages          65530`
  - `Modified db pages       3`
  - `innodb_io_capacity`: can quickly starve data reads and writes to the transaction log if you set this too high.
- https://dev.mysql.com/doc/refman/8.0/en/optimizing-innodb-diskio.html
  - lower `innodb_io_capacity` if not strictly needed
- check percona book

other references:

- mac reference: https://apple.stackexchange.com/questions/193883/to-have-ram-based-filesystem-in-osx
- https://www.cybertec-postgresql.com/en/postgresql-parallel-create-index-for-better-performance
