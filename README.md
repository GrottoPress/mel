# Mel

**Mel** is an asychronous event-driven jobs processing engine designed to scale. *Mel* simplifies jobs management by abstracting away the nuances of scheduling and running jobs.

In *Mel*, a scheduled job is called a *task*. A single job may be scheduled in multiple ways, yielding multiple tasks from the same job.

*Mel* schedules all tasks in *Redis*, as a set of task `id`s sorted by their times of next run. For recurring tasks, the next run is scheduled in *Redis* right before the current run runs.

This makes *Redis* the *source of truth* for schedules, allowing to easily scale out *Mel* to multiple instances (called *workers*), or replace or stop workers without losing schedules.

*Mel* supports *bulk scheduling* of jobs as a single atomic unit. There's also support for *sequential scheduling* to track a series of jobs and perform some action after they are all complete.

### Types of tasks

1. **Instant Tasks:** These are tasks that run only once after they are scheduled, either immediately or at some specified time in the future.

1. **Periodic Tasks:** These are tasks that run regularly at a specified interval. They may run forever, or till some specified time in the future.

1. **Cron Tasks:** These are tasks that run according to a specified schedule in *Unix Cron* format. They may run forever, or till some specified time in the future.

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

   Mel.configure do |settings|
     settings.batch_size = 10 # <= Maximum tasks to retrieve per poll (Optional)
     settings.log_backend = Log::IOBackend.new
     settings.log_level = :info
     settings.poll_interval = 3.seconds
     settings.redis_pool_size = 25
     settings.redis_url = "redis://localhost:6379/0"
     settings.timezone = Time::Location.load("Africa/Accra")
   end

   # ...
   ```

## Usage

1. Define job:

   ```crystal
   # ->>> src/jobs/do_some_work.cr

   class DoSomeWork
     include Mel::Job # <= Required

     def initialize(@arg_1 : Int32, @arg_2 : String)
     end
     # <= Instance vars must be JSON-serializable

     # (Required)
     #
     # Main operation to be performed.
     # Called in a new fiber.
     def run
       # << Do work here >>
     end

     # Called in the main fiber, before spawning the fiber
     # that calls the `#run` method above.
     def before_run
       # ...
     end

     # Called in the same fiber that calls `#run`.
     # `success` is `true` only if the run succeeded.
     def after_run(success)
       if success
         # ...
       else
         # ...
       end
     end

     # Called in the main fiber before enqueueing the task in
     # Redis.
     def before_enqueue
       # ...
     end

     # Called in the main fiber after enqueueing the task in
     # Redis. `success` is `true` only if the enqueue succeeded.
     def after_enqueue(success)
       if success
         # ...
       else
         # ...
       end
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

     The given `Time::Span` can be negative. Eg: `DoSomeWork.run_in(-5.minutes, ...)`. This may be useful for prioritizing certain tasks.

   - Run job at specific time:

     ```crystal
     # ->>> src/app/some_file.cr

     DoSomeWork.run_at(10.minutes.from_now, arg_1: 5, arg_2: "value")
     ```

     The specified `Time` can be in the past. Eg: `DoSomeWork.run_at(-10.minutes.from_now, ...)`. This may be useful for prioritizing certain tasks.

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

   The `DoSomeWork.run_*` methods accept the following additional arguments:

   - `retries`: Number of times to attempt a task after it fails, before giving up. Default: `2`. Eg: `DoSomeWork.run(... retries: 1, ...)`

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

     Spec.before_each { Mel::Task::Query.truncate }

     Spec.after_suite do
       Mel.stop
       Mel::Task::Query.truncate
     end
     # <= `Mel.stop` waits for all running tasks to complete before exiting

     spawn { Mel.start }

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

### Specifying task IDs

You may specify an ID whenever you schedule a new job, thus: `DoSomeWork.run_*(... id: "1001", ...)`. If not specified, *Mel* automatically generates a unique **dynamic** ID for the task.

Dynamic task IDs may be OK for *triggered* jobs (jobs triggered by some kind of user interaction), such as a job that sends an email notification whenever a user logs in.

However, there may be jobs that are scheduled unconditionally when your app starts (*global* jobs). For example, sending invoices at the beginning of every month. You should specify unique **static** IDs for such tasks.

Otherwise, every time the app (re)starts, jobs are scheduled again, each time with a different set of IDs. *Redis* would accept the new schedules because the IDs are different, resulting in duplicated scheduling of the same jobs.

This is particularly important if you run multiple instances of your app. Hardcoding IDs for *global* jobs means that all instances hold the same IDs, so cannot reschedule a job that has already been scheduled by another instance.

A task ID may be a mixture of static and dynamic parts. For instance, you may include the current month and year for a global job that runs once a month, to ensure it is never scheduled twice within the same month.

### Bulk scheduling

A common pattern is to break up long-running tasks into smaller tasks. For example:

```crystal
class SendAllEmails
  include Mel::Job

  def initialize(@users : Array(User))
  end

  def run
    @users.each { |user| send_email(user) }
  end

  private def send_email(user)
    # Send email
  end
end

# Schedule job
users = # ...
SendAllEmails.run(users: users)
```

The above job would run in a single fiber, managed by whichever worker pulls this task at run time. This could mean too much work for a single worker if the number of users is sufficiently large.

The preferred approach is to define a job that sends email to one user, and schedule that job for as many users as needed:

```crystal
class SendEmail
  include Mel::Job

  def initialize(@user : User)
  end

  def run
    send_email(@user)
  end

  private def send_email(user)
    # Send email
  end
end

class SendAllEmails
  include Mel::Job

  def initialize(@users : Array(User))
  end

  def run
    return if @users.empty?

    # Pushes all jobs atomically, at the end of the block.
    run do |redis|
      @users.each { |user| SendEmail.run(redis: redis, user: user) }
    end
  end
end

# Schedule job
users = # ...
SendAllEmails.run(users: users)
# <= Any `.run_*` method could be called here, as with any job.
```

### Sequential scheduling

Bulk scheduling works OK as a *fire-and-forget* mechanism. However, you may need to keep track of a series of jobs as a single unit, and perform some action only after the last job is done.

This is where sequential scheduling comes in handy. *Mel*'s event-driven design allows chaining jobs, by scheduling the next after the current one completes:

```crystal
class SendAllEmails
  include Mel::Job

  def initialize(@users : Array(User))
  end

  def run
    @users[0]?.try do |user|
      send_email(user) # <= Send first email
    end
  end

  def after_run(success)
    return unless success

    if @users[1]?
      self.class.run(users: @users[1..]) # <= Schedule next email
    else # <= All emails have been sent
      # Do something
    end
  end

  private def send_email(user)
    # Send email
  end
end

# Schedule job
users = # ...
SendAllEmails.run(users: users)
```

### Optimization

*Mel*'s focus is on scaling out to multiple workers without hiccups. Each worker polls *Redis* every configurable period. Hard work has gone into reducing the number of queries made, which may be critical for performance.

There is only one queue in *Mel* on which all tasks are scheduled. When a worker polls redis, it makes **only one** query for due tasks. If any tasks are due, one more query is made to retrieve the actual task objects (JSON).

This means, each worker makes no more than two queries for every poll. When a worker runs a task, it may make a query to reschedule the task if it fails, or to schedule the next run if it is a recurring task.

Keep these in mind when configuring your poll interval, or deciding the number of workers to run.

### Graceful shutdown

A *Mel* worker waits for all running tasks to complete before exiting, if it received a `Signal::INT` or a `Signal::TERM`, or if you called `Mel.stop` somewhere in your code.

This means jobs are never lost mid-flight. However, because workers pull due tasks from *Redis* **destructively**, if there is a force shutdown (eg: a power cut), running tasks may be lost.

## Development

Create a `.env.sh` file:

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
