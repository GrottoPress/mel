# Mel

**Mel** is an asychronous event-driven jobs processing engine designed to scale. *Mel* simplifies jobs management by abstracting away the nuances of scheduling and running jobs.

In *Mel*, a scheduled job is called a *task*. A single job may be scheduled in multiple ways, yielding multiple tasks from the same job.

*Mel* schedules all tasks in *Redis*, as a set of task `id`s sorted by their times of next run. For recurring tasks, the next run is scheduled in *Redis* right after the current run completes.

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
     settings.error_handler = ->(error : Exception) { puts error.message }
     settings.redis_url = "redis://localhost:6379/0?initial_pool_size=5&max_idle_pool_size=10"
     settings.redis_key_prefix = "mel"
     settings.timezone = Time::Location.load("Africa/Accra")
   end

   Log.setup(Mel.log.source, :info, Log::IOBackend.new)
   Redis::Connection::LOG.level = :info

   # ...
   ```

## Usage

1. Define job:

   ```crystal
   # ->>> src/jobs/do_some_work.cr

   struct DoSomeWork
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

   - `retries`: Number of times to attempt a task after it fails, before giving up. This could be specified as a simple integer (eg: `3`), or a list of backoffs (eg: `{2, 4, 1}`, or `{2.seconds, 4.seconds, 1.second}`). Default: `{1, 2}`. A task fails when any exception is raised during run.

1. Start *Mel*:

   - As its own process (compiled separately):

     ```crystal
     # ->>> src/worker.cr

     require "mel/worker"

     require "./app/**"

     Mel.configure do |settings|
       settings.batch_size = -100
       settings.poll_interval = 15.seconds
       settings.worker_id = ENV["WORKER_ID"].to_i
     end

     Mel.start
     # <= Blocks forever, polls for due tasks and runs them.
     # <= You may stop Mel by sending `Signal::INT` or `Signal::TERM`.
     # <= Mel will wait for all running tasks to complete before exiting.
     ```

   - As part of your app (useful for testing):

     ```crystal
     # ->>> spec/spec_helper.cr

     # ...

     require "mel/spec"

     Mel.configure do |settings|
       settings.batch_size = -1
       settings.poll_interval = 1.millisecond
       settings.worker_id = 1
     end

     Spec.before_each { Mel::Task::Query.truncate }

     Spec.after_suite do
       Mel.stop
       Mel::Task::Query.truncate
     end
     # <= `Mel.stop` waits for all running tasks to complete before exiting

     Mel.start_async

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

### Job templates

A job's `.run_*` methods allow scheduling that single job in multiple ways. However, there may be situations where you need to schedule a job the same way, every time.

*Mel* comes with `Mel::Job::Now`, `Mel::Job::In`, `Mel::Job::At`, `Mel::Job::Every` and `Mel::Job::On` templates to do exactly this:

```crystal
# Define job
struct DoSomeWorkNow
  include Mel::Job::Now # <= Required

  def initialize(@arg_1 : Int32, @arg_2 : String)
  end

  # (Required)
  def run
    # << Do work here >>
  end
end

# Schedule job
DoSomeWorkNow.run(arg_1: 5, arg_2: "value")
# <= Alias: `DoSomeWorkNow.run_now(...)`
```

```crystal
# Define job
struct DoSomeWorkIn
  include Mel::Job::In # <= Required

  def initialize(@arg_1 : Int32, @arg_2 : String)
  end

  # (Required)
  def run
    # << Do work here >>
  end
end

# Schedule job
DoSomeWorkIn.run_in(10.minutes, arg_1: 5, arg_2: "value")
```

```crystal
# Define job
struct DoSomeWorkAt
  include Mel::Job::At # <= Required

  def initialize(@arg_1 : Int32, @arg_2 : String)
  end

  # (Required)
  def run
    # << Do work here >>
  end
end

# Schedule job
DoSomeWorkAt.run_at(Time.local(2021, 6, 9, 5), arg_1: 5, arg_2: "value")
```

```crystal
# Define job
struct DoSomeWorkEvery
  include Mel::Job::Every # <= Required

  def initialize(@arg_1 : Int32, @arg_2 : String)
  end

  # (Required)
  def run
    # << Do work here >>
  end
end

# Schedule job
DoSomeWorkEvery.run_every(2.hours, arg_1: 5, arg_2: "value")
# <= Overload: `.run_every 2.hours, for: 5.hours`
# <= Overload: `.run_every 2.hours, till: 9.hours.from_now`
```

```crystal
# Define job
struct DoSomeWorkOn
  include Mel::Job::On # <= Required

  def initialize(@arg_1 : Int32, @arg_2 : String)
  end

  # (Required)
  def run
    # << Do work here >>
  end
end

# Schedule job
DoSomeWorkOn.run_on("0 8 1 * *", arg_1: 5, arg_2: "value")
# <= Overload: `.run_on "0 8 1 * *", for: 100.weeks`
# <= Overload: `.run_on "0 8 1 * *", till: Time.local(2099, 12, 31)`
```

A template excludes all methods not relevant to that template. For instance, calling `.run_every` or `.run_now` for a `Mel::Job::At` template won't compile.

All other methods and callbacks usable in a regular job may be used in a template, including `before_*` and `after_*` callbacks.

You may `include` more than one template in a single job. For instance, including `Mel::Job::At` and `Mel::Job::Every` in a job means you can call `.run_at` and `.run_every` methods for that job.

Additionally, *Mel* comes with two grouped templates: `Mel::Job::Instant` and `Mel::Job::Recurring`.

`Mel::Job::Instant` is equivalent to `Mel::Job::Now`, `Mel::Job::In` and `Mel::Job::At` combined. `Mel::Job::Recurring` is the equivalent of `Mel::Job::Every` and `Mel::Job::On` combined.

`Mel::Job` is itself a grouped template that combines all the other templates.

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
struct SendAllEmails
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

Moreover, some mails may be sent multiple times if the task is retried as a result of failure. Ideally, jobs should be idempotent, and as atomic as possible.

The preferred approach is to define a job that sends email to one user, and schedule that job for as many users as needed:

```crystal
struct SendAllEmails
  include Mel::Job

  def initialize(@users : Array(User))
  end

  def run
    return if @users.empty?

    # Pushes all jobs atomically, at the end of the block.
    #
    # There's also `redis#pipeline(&)`, if you do not need the atomicity.
    redis.multi do |redis|
      # Pass `redis` to `.run_*`.
      @users.each { |user| SendEmail.run(redis: redis, user: user) }
    end
  end

  struct SendEmail
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
struct SendAllEmails
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

Although the example above involves a single job, sequential scheduling can be applied to multiple different jobs, each representing a step in a workflow, with each job scheduling the next job in its `#after_run` callback:

```crystal
struct SomeJob
  include Mel::Job
  
  def run
    # Do something
  end

  def after_run(success)
    SomeStep.run if success
  end

  struct SomeStep
    include Mel::Job

    def run
      # Do something
    end

    def after_run(success)
      SomeOtherStep.run if success
    end
  end

  struct SomeOtherStep
    include Mel::Job

    def run
      # Do something
    end

    def after_run(success)
      # All done; do something
    end
  end
end
```

### Tracking progress

*Mel* provides a progress tracker for jobs. This is particularly useful for tracking multiple jobs representing a series of steps in a workflow:

```crystal
# ->>> src/app/config.cr

# ...

Mel.configure do |settings|
  settings.progress_expiry = 1.day
end

# ...
```

```crystal
# ->>> src/jobs/some_job.cr

struct SomeJob
  include Mel::Job

  def initialize
    @progress = Mel::Progress.start(id: "some_job", description: "Awesome job")
  end

  # ...

  def after_run(success)
    return @progress.fail unless success

    SomeStep.run(progress: @progress)
    @progress.move(50) # <= Move to 50%
  end

  struct SomeStep
    include Mel::Job::Now

    def initialize(@progress : Mel::Progress)
    end

    # ...

    def after_run(success)
      return @progress.fail unless success

      SomeOtherStep.run(progress: @progress)
      @progress.move(80) # <= Move to 80%
    end
  end

  struct SomeOtherStep
    include Mel::Job::Now

    def initialize(@progress : Mel::Progress)
    end

    # ...

    def after_run(success)
      return @progress.fail unless success
      @progress.succeed # <= Move to 100%
    end
  end
end

# Schedule job
SomeJob.run

# Track progress
#
# This may, for instance, be used in a route in a web application.
# Client-side javascipt can query this route periodically, and
# show response using a progress tracker UI.
#
report = Mel::Progress.track("some_job")

report.try do |_report|
  _report.description
  _report.id
  _report.value

  _report.failure?
  _report.running?
  _report.success?

  _report.started?
  _report.ended?
end
```

You may delete progress data in specs thus:

```crystal
# ->>> spec/spec_helper.cr

# ...

Spec.before_each do
  # ...
  Mel::Progress::Query.truncate
  # ...
end

Spec.after_suite do
  # ...
  Mel::Progress::Query.truncate
  # ...
end

# ...
```

### Jobs *security*

A *Mel* worker waits for all running tasks to complete before exiting, if it received a `Signal::INT` or a `Signal::TERM`, or if you called `Mel.stop` somewhere in your code. This means jobs are never lost mid-flight.

Jobs are not lost even if there is a force shutdown of the worker process, since *Mel* does not delete a task from *Redis* until it is complete. The worker can pick off where it left off when it comes back online.

*Mel* relies on the `worker_id` setting to achieve this. Each worker, therefore, must set a *unique*, *static* integer ID, so it knows which *pending* tasks it owns.

Once a task enters the *pending* state, only the worker that put it in that state can run it. So if you need to take down a worker permanently, ensure that it completes all pending tasks by sending the appropriate signal.

### Scaling out

Because each worker requires it's own unique `.worker_id`, autoscaling as used in classic distributed architectures should not be used, since auto-scaled replicas would inherit the same configuration as the original instance.

This would lead to multiple workers using the same `.worker_id`, which could result in pending jobs being run multiple times; once each for each replica that starts up.

Instead, it is recommended that a new service be registered for each worker that is to be deployed, and the appropriate `.worker_id` set for each.

- Using `Procfile`:

  ```procfile
  # ->> Procfile

  # ...
  worker_1: export WORKER_ID=1 && ./bin/worker
  worker_2: export WORKER_ID=2 && ./bin/worker
  worker_3: export WORKER_ID=3 && ./bin/worker
  # ...
  ```

- Using docker compose for swarm:

  ```yaml
  # ->> docker-compose.yml

  # ...
  services:
    worker_1:
      command: ./bin/worker
      environment:
        WORKER_ID: "1"
      deploy:
        replicas: 1
    worker_2:
      command: ./bin/worker
      environment:
        WORKER_ID: "2"
      deploy:
        replicas: 1
    worker_3:
      command: ./bin/worker
      environment:
        WORKER_ID: "3"
      deploy:
        replicas: 1
  # ...
  ```

Another option is to accept the worker ID as a command argument:

```crystal
# ->> src/worker.cr

# ...
ARGV.first?.try { |worker_id| Mel.settings.worker_id = worker_id.to_i }

Mel.start
```

- Using `Procfile`:

  ```procfile
  # ->> Procfile

  # ...
  worker_1: ./bin/worker 1
  worker_2: ./bin/worker 2
  worker_3: ./bin/worker 3
  # ...
  ```

- Using docker compose for swarm:

  ```yaml
  # ->> docker-compose.yml

  # ...
  services:
    worker_1:
      command: ./bin/worker 1
      deploy:
        replicas: 1
    worker_2:
      command: ./bin/worker 2
      deploy:
        replicas: 1
    worker_3:
      command: ./bin/worker 3
      deploy:
        replicas: 1
  # ...
  ```

- Using config for [Fly.io](https://fly.io):

  ```toml
  # ->> fly.toml

  # ...
  [processes]
    worker_1 = './bin/worker 1'
    worker_2 = './bin/worker 2'
    worker_3 = './bin/worker 3'
  # ...
  ```

  Ensure no spare machines are created by passing `--ha=false` to `fly deploy` command.

### Smart polling

*Mel*'s `batch_size` setting allow setting a limit on the number of due tasks to retrieve and run each poll, and, consequently, the number of fibers spawned to handle those tasks.

If the setting is a positive integer `N`, *Mel* would pull and run `N` due tasks each poll.

If it is a negative integer `-N`  (other than `-1`), the number of due tasks pulled and ran each poll would vary such that the total number of running tasks would not be greater than `N`.

`-1` sets *no* limits. *Mel* would pull as many tasks as are due each poll, and run all of them.

## Integrations

### *Carbon* mailer

<small>Link: https://github.com/luckyframework/carbon</small>

1. Require `mel/carbon`, after your emails:

   ```crystal
   # ->>> src/app.cr

   # ...
   require "emails/base_email"
   require "emails/**"

   require "mel/carbon"
   # ...
   ```

1. Set up base email:

   ```crystal
   # ->>> src/emails/base_email.cr

   abstract class BaseEmail < Carbon::Email
     # ...
     include JSON::Serializable
     # ...
   end
   ```

1. Configure deliver later strategy:

   ```crystal
   # ->>> config/email.cr

   BaseEmail.configure do |settings|
     # ...
     settings.deliver_later_strategy = Mel::Carbon::DeliverLaterStrategy.new
     # ...
   end
   ```

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
