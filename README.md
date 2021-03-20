# Mel

**Mel** is an asychronous jobs processing engine designed to scale. *Mel* simplifies jobs management by abstracting away the nuances of scheduling and running jobs.

In *Mel*, a scheduled job is called a *task*. A single job may be scheduled in multiple ways, yielding multiple tasks from the same job.

*Mel* schedules all tasks in *Redis*, as a set of task `id`s sorted by their times of next run. For recurring tasks, the next run is scheduled in *Redis* right before the current run runs.

This makes *Redis* the *source of truth* for schedules, allowing to easily scale out *Mel* to multiple instances (called *workers*), or replace or stop workers without losing schedules.

### Types of tasks

1. **Instant Tasks:** These are tasks that run only once after they are scheduled, either immediately or at some specified time in the future.

1. **Periodic Tasks:** These are tasks that run regularly at a specified interval. They may run forever, or till some specified time in the future.

1. **Cron Tasks:** These are tasks that run according a specified schedule in *Unix Cron* format. They may run forever, or till some specified time in the future.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     mel:
       github: GrottoPress/mel
   ```

1. Run `shards update`

1. Require and configure *Mel*:

   ```crystal
   # ->>> src/app/config.cr

   # ...

   require "mel"

   require "../jobs/**"

   Mel.configure do |config|
     config.batch_size = 10 # <= Maximum tasks to retrieve per poll (Optional)
     config.poll_interval = 3.seconds
     config.redis_url = "redis://localhost:6379/0"
     config.redis_pool_size = 25
     config.timezone = Time::Location.load("Africa/Accra")
   end

   # ...
   ```

## Usage

1. Define job:

   ```crystal
   # ->>> src/jobs/do_some_work.cr

   require "mel"

   class DoSomeWork
     include Mel::Job # <= Required

     def initialize(@arg_1 : Int32, @arg_2 : String)
     end
     # <= Instance vars must be JSON-serializable

     def run # <= Required
       # << Do work here >>
     end
   end
   ```

1. Schedule job:

   - Run job now:

     ```crystal
     # ->>> src/app/some_file.cr

     DoSomeWork.run(arg_1: 5, arg_2: "value")
     # <= Alias: DoSomeWork.run_now(...)
     ```

   - Run job after given delay:

     ```crystal
     # ->>> src/app/some_file.cr

     DoSomeWork.run_in(5.minutes, arg_1: 5, arg_2: "value")
     ```

   - Run job at specific time:

     ```crystal
     # ->>> src/app/some_file.cr

     DoSomeWork.run_at(1.minute.from_now, arg_1: 5, arg_2: "value")
     ```

   - Run periodically:

     ```crystal
     # ->>> src/app/some_file.cr

     DoSomeWork.run_every(10.minutes, for: 1.hour, arg_1: 5, arg_2: "value")
     ```

     Instead of `for:`, you may use `till:` and specify a `Time`. Leave those out to run forever.

   - Run on a Cron schedule:

     ```crystal
     # ->>> src/app/some_file.cr

     DoSomeWork.run_on("0 */2 * * *", for: 6.hours, arg_1: 5, arg_2: "value")
     ```

     Instead of `for:`, you may use `till:` and specify a `Time`. Leave those out to run forever.

1. Start *Mel*:

   - As its own process (compiled separately):

     ```crystal
     # ->>> src/worker.cr

     require "./app/**"

     Mel.start
     # <= Blocks forever, polls for due tasks and runs them.
     # <= You may stop Mel by sending `Signal::INT` or `Signal::TERM`.
     # <= Mel will wait for all running tasks to complete before exiting.
     ```

   - As part of your app (useful for testing):

     ```crystal
     # ->>> spec/spec_helper.cr

     # ...

     spawn { Mel.start }

     Spec.after_suite { Mel.stop }
     # <= `Mel.stop` waits for all running tasks to complete before exiting

     # ...
     ```

1. Configure compile targets:

   ```yaml
   # ->>> shard.yml

   # ...

   targets:
     app:
       main: src/app.cr
     worker:
       main: src/worker.cr

   # ...
   ```

### Triggered vs. Global jobs

By default, whenever any `SomeJob.run_*` method is called, *Mel* creates a new task (with a unique ID) for the job and schedules it in *Redis*. This may be OK for *triggered* jobs (jobs triggered by some kind of user interaction).

For example, you may define a job to send an email notification whenever a user logs in. Each email notification is a unique task tied to a particular login instance. You should **never** hardcode IDs, or use an idempotent method to generate IDs, for such jobs.

However, there may be jobs that are scheduled unconditionally when your app starts (*global* jobs). For example, sending invoices at the beginning of every month. You should specify unique **hardcoded** IDs for such tasks.

Otherwise, every time the app (re)starts, jobs are scheduled again, each time with a different set of IDs. *Redis* would accept the new schedules because the IDs are different, resulting in duplicated scheduling of the same jobs.

This is particularly important if you run multiple instances of your app. Hardcoding IDs for *global* jobs means that all instances hold the same IDs, so cannot reschedule a job that has already been scheduled by another instance.

To specify an ID: `SomeJob.run_*(id: "1001", ...)`. Do **not** generate the ID with any *method* or *macro* call -- **hardcode** it, making sure it's unique.

In sum, you need to consider whether or not a job you defined should create a new task every time a call to run the job is encountered. If yes, do not specify an ID (*Mel* would generate one every time). Otherwise, specify a hardcoded ID.

### Optimization

*Mel*'s focus is on scaling out to multiple workers without hiccups. Each worker polls *Redis* every configurable period. Hard work has gone into reducing the number of queries made, which may be critical for performance.

There is only one queue in *Mel* on which all tasks are scheduled. When a worker polls redis, it makes **only one** query for due tasks. If any tasks are due, one more query is made to retrieve the actual task objects (JSON).

This means, each worker makes no more than two queries for every poll. When a worker runs a task, it may make a query to reschedule the task if it fails, or to schedule the next run if it is a recurring task.

Keep these in mind when configuring your poll interval, or deciding the number of workers to run.

### Graceful shutdown

A *Mel* worker waits for all running tasks to complete before exiting, if it received a `Signal::INT` or a `Signal::TERM`, or if you called `Mel.stop` somewhere in your code.

This means jobs are never lost mid-flight. However, because workers pull due tasks from *Redis* **destructively**, if there is a force shutdown (eg: a power cut), running tasks may be lost.

## Development

Run tests with `docker-compose run --rm spec`. If you need to update shards before that, run `docker-compose run --rm shards`.

If you would rather run tests on your local machine (ie, without docker), create a `.env.sh` file:

```bash
#!/bin/bash

export REDIS_URL='redis://localhost:6379/0'
```

Update the file with your own details. Then run tests with `source .env.sh && crystal spec -Dpreview_mt`.

## Contributing

1. [Fork it](https://github.com/GrottoPress/mel/fork)
1. Switch to the `master` branch: `git checkout master`
1. Create your feature branch: `git checkout -b my-new-feature`
1. Make your changes, updating changelog and documentation as appropriate.
1. Commit your changes: `git commit`
1. Push to the branch: `git push origin my-new-feature`
1. Submit a new *Pull Request* against the `GrottoPress:master` branch.

## Security

Kindly report suspected security vulnerabilities in private, via contact details outlined in this repository's `.security.txt` file.
