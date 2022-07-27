---
layout: post
title: "Unexpected things users will find when moving from metal to the cloud (AWS)"
tags: [aws,cloud,sysadmin]
last_modified_at: 2022-07-27 13:50:42
---

It's a well-known fact that when moving from metal to the cloud, costs will typically increase (hopefully, trading it for reduced maintenance and/or increased system resilience).

There are some important things that are very hard to assess, before moving to the cloud service itself.

We moved, long ago, to AWS, and we had certain surprises; in this article, I'll describe them, so that companies that plan to move to the cloud can make more informed decisions.

This article is updated to Jul/2022, and I will update it if/when I'll found other notable things.

Content:

- [Disks (EBS), also for database services, have an I/O budget](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#disks-ebs-also-for-database-services-have-an-io-budget)
  - [The bottom line](#the-bottom-line)
- [Storage services can't be stopped](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#storage-services-cant-be-stopped)
  - [The bottom line](#the-bottom-line-1)
- [Last generation database services may not be necessarily reserved if they're Intel/AMD](/Unexpected-facts-to-account-when-moving-from-metal-to-the-cloud-AWS-#last-generation-database-services-may-not-be-necessarily-reserved-if-theyre-intelamd)
  - [The bottom line](#the-bottom-line-2)

## Disks (EBS), also for database services, have an I/O budget

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
