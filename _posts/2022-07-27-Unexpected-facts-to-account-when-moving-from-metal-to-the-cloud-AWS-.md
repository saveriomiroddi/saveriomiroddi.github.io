---
layout: post
title: "Unexpected things users will find when moving from metal to the cloud (AWS)"
tags: [aws,cloud,sysadmin]
last_modified_at: 2023-09-13 13:10:26
---

It's a well-known fact that when moving from metal to the cloud, costs will typically increase (hopefully, trading it for reduced maintenance and/or increased system resilience).

There are some important things that are very hard to assess, before moving to the cloud service itself.

We moved, long ago, to AWS, and we had certain surprises; in this article, I'll describe them, so that companies that plan to move to the cloud can make more informed decisions.

This article is updated to Sep/2023, and I will update it if/when I'll found other notable things.

Content:

- [Some workflows have unknown side effects, and can be completely obscure even in case of very serious problems](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#some-workflows-have-unknown-side-effects-and-can-be-completely-obscure-even-in-case-of-very-serious-problems)
  - [An RDS horror story](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#an-rds-horror-story)
  - [The bottom line](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#the-bottom-line)
- [Storage services can't be stopped](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#storage-services-cant-be-stopped)
  - [The bottom line](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#the-bottom-line-1)
- [Last generation database services may not be necessarily reserved if they're Intel/AMD](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#last-generation-database-services-may-not-be-necessarily-reserved-if-theyre-intelamd)
  - [The bottom line](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#the-bottom-line-2)
- [Service upgrades have unpredictable downtime](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#service-upgrades-have-unpredictable-downtime)
  - [The bottom line](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#the-bottom-line-3)
- [(OBSOLETE) Disks (EBS), also for database services, have an I/O budget](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#obsolete-disks-ebs-also-for-database-services-have-an-io-budget)
  - [The bottom line](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#the-bottom-line-4)

## Some workflows have unknown side effects, and can be completely opaque even in case of very serious problems

In several cases, AWS doesn't disclose the side effects (that is, downtime) of their workflows, declaring that the workflow is "best-effort".

[This](https://web.archive.org/web/20230323222748/https://docs.aws.amazon.com/AmazonRDS/latest/AuroraMySQLReleaseNotes/AuroraMySQL.Updates.117.html) is an example of Aurora MySQL update:

> We support zero-downtime patching, which works on a best-effort basis to preserve client connections through the patching process

Note how the workflow is described "zero-downtime" and "best-effort" at the same time, which is conflictual.

Worse, some workflows can be completely opaque, even in case of very serious problems (see following section)

### An RDS horror story

One of our primary MySQL RDS instances hung, due to problems with fulltext indexes (MySQL's fulltext implementation has very serious problems).

The only options we had were to reboot the server, or to perform a failover; for simplicity, we opted for the former.

However, after 10 minutes or so, the instance was stuck in the `Rebooting` state, with the logs not showing anything useful.

Even after 30 minutes, the server was still stuck with no indication of what was the nature of the problem. We contacted support (we have a business plan), but the first line was not able to do anything, so they told us they would contact the RDS team.

At around the 45 minute mark, we were in serious troubles:

- production was down
- we had no clue about what was going on
- we had no control over the instance
- support was not helping

therefore we decided to perform the failover.

At some point, the instance finally rebooted, however, in order to avoid mistakes (due to id clashing), we decided to stop it, and perform investigations later.

When it came the moment to perform the investigation, the logs weren't showing anything useful, so we asked the AWS support to investigate.

It took *more than two weeks*, and multiple requests, for the AWS support to come with a reply, and ultimately, they replied that there had been a problem with the server restart, but since we stopped the instance, there were no logs to look at.

With the information at hand, it seems that AWS did not disclose what really happened behind the scenes, giving us generic information; it doesn't make sense for a MySQL server to take multiple restarts in order to successfully go online.

Cases like this are terrifying. An RDS instance may hang, bringing production down, and the sysadmin may not have any mean to restore it, nor any information about the problem; the only solution is then to either wait a very long time, hoping that the problem will solve itself, or perform a failover (assuming one has a read replica).

### The bottom line

Some common workflows (e.g. service updates) have unknown side effects (i.e. downtime), so systems need to be engineered to deal with this. This is a very important distinction from owned services: while engineering for failure is certainly required, at least one is under control of the workflows.

In worst case scenario, AWS services like RDS may fail catastrophically, and the sysadmin may be left without any mean to intervene (e.g. if they have no read replicas) and/or information to understand what's the problem.

## Storage services can't be stopped

One would think that they can stop certain services, and resume them when they wish, while paying for the storage only in the meantime.

This is not possible. There is one excetion, RDS (database), whose services can be stopped, but they restart automatically after one week (!). This is so undesirable in our case, that we wrote a Lambda that stops RDS instances when they're not explicitly turned on.

### The bottom line

AWS storage services can't be stopped. The only exception is RDS (databases), but it needs code to be written, in order to keep it stopped.

## Last generation database services may not be necessarily reserved if they're Intel/AMD

AWS has introduced, in the last years, their own ARM hardware; thins includes the platforms for database services.

For AWS customers, it's crucial to reserve database instances, which are typically a (very) large part of the bill.

When the new generation of RDS instances was introduced (6th), only ARM could be reserved at first; it took (I estimate) a few months, for the reservations to available on Intel/AMD as well.

This meant that user requiring a reservation in the meantime, either had to switch to ARM, or to use an older RDS generation.

### The bottom line

It is possible (but not necessarily) that for some periods of time, RDS reservations are only available for ARM instances and older Intel/AMD generations, but not for new Intel/AMD ones.

## Service upgrades have unpredictable downtime

AWS doesn't set any specification of the downtime caused by service upgrades; the documentation is typically fuzzy (reporting a "best effort" approach), and the upgrades have imprecise timespans, without any indication.

For example, even if one has a redundant Elastcache cluster, and an upgrade specifies "up to 30 minutes" per node, there is no indication about when, within the allocated time (say, 30 minutes * 2 node = 1 hour!), the connection will drop, and for how long.

This means that if the application has no measures against sudden connection drops, over the whole application, it will experience unpredictable disruption of service during the upgrade.

### The bottom line

The application must have measures against connection drops from *all* the services, *all over* the application, even for services configured with redundant topologies. If this is not the case, unpredictable disruption of service will be experienced during service upgrades.

## (OBSOLETE) Disks (EBS), also for database services, have an I/O budget

(This section is now obsolete, as the `gp3` storage type has been made available both for EC2 and RDS instances)

Even when an application doesn't make heavy use of disks, it happens sometimes that a certain event will trigger heavy I/O load, at least for a short time.

In AWS, disks (EBS) have three main properties:

- a max I/O budget
- a refill I/O rate (I/O automatically refills at a certain rate)
- a minimum guaranteed I/O

If/when the application does heavy I/O, it risks to drain the I/O budget, therefore reaching the minimum guaranteed I/O. Even if such events are rare, they surely happen on any application, and they must be taken into account, since they can cause insufficient performance or even downtime.

There are two strategies to handle this:

1. make sure that heavy I/O never happens, and/or make the application I/O aware (e.g. by limiting writes), so that the application _never_ crosses a certain I/O threshold (or anyway, not for longer than a certain timeframe);
2. increase the size of the disks (the refill rate is proportional to the disk size), so that even if the application performs heavy I/O, the budget refill quickly compensates the expenditure.

Both solutions have an expense.

Option (1) is possible, however, making the application handle I/O with certainty is a nontrivial task from a development perspective (that is, development cost), and it's a continuous job (since typically, applications add new features).

Option (2) is easy to apply, but it has a monetary cost; large part of the disks will be left unused, which is undesirable.

AWS has recently (2022) introduced the `gp3` disks, which have a high baseline, therefore, resolving the I/O budget problem. Cunningly though, AWS doesn't offer this disk type for RDS users, which are stuck with this problem, and related cost.

### The bottom line

If an application has I/O peaks (e.g updates dozens of millions of records in the database), even if seldom, the user must very carefully plan I/O costs, when moving to AWS.
