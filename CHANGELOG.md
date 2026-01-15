# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.1.2] - 2026-01-15

### Changed
- Allow *Redis* shard's retries together with `&retry_attempts` query parameter

## [1.1.1] - 2026-01-14

### Fixed
- Use the value of `&retry_attempts` query parameter for retries

## [1.1.0] - 2026-01-12

### Added
- Add `Mel::Postgres` adapter
- Add `#be_enqueued` spec expectation

### Changed
- Bump minimum required Crystal version to 1.4

### Changed
- Move Lua script into its own file

## [1.0.3] - 2025-12-23

### Fixed
- Fix `ArgumentError` with `jgaskins/redis` v0.14

## [1.0.2] - 2025-10-28

### Fixed
- Add support for Crystal v1.8

## [1.0.1] - 2025-06-06

### Fixed
- Create a new object in `RunPool.delete` to avoid eventual memory leak
- Fix compile error calling `.compare_versions` with `Mel::VERSION`

## [1.0.0] - 2025-04-18

### Changed
- Make `Mel::Settings` module private
- Convert `Mel::Memory` into a `struct`
- Convert `Mel::Redis` into a `struct`
- Rename `Mel::Store::Transaction` to `Mel::Transaction`
- Rename `Mel::Task::RunQueue` to `Mel::RunPool`

### Removed
- Remove `Mel::Job::Template#transaction` helper

## [0.24.0] - 2025-03-22

### Added
- Add `Mel::Task::RunQueue` that saves a workers running tasks in memory

### Removed
- Remove `Mel::Task::Env`

## [0.23.2] - 2025-03-22

### Fixed
- Replace `loadstring()` with `string.gmatch()` in embedded Lua script

## [0.23.1] - 2025-03-22

### Changed
- Make `Mel::Settings` module public

### Fixed
- Ensure orphan period is never less than 1 second

## [0.23.0] - 2025-03-20

### Added
- Add `Mel::Task::Env` that saves a workers running tasks in the environment

### Removed
- Remove `.worker_id` setting
- Remove `.find_pending` class methods

## [0.22.0] - 2024-08-05

### Changed
- Change transaction constructors to accept parent store instance as argument

## [0.21.0] - 2024-08-02

### Added
- Add support for custom storage backends
- Add memory storage backend
- Add `Mel::Job::Template#run` abstract method

### Changed
- Rename `Mel::Carbon::DeliverLaterStrategy` to `DeliverLater`
- Remove `src/worker.cr`

## [0.20.0] - 2024-04-16

### Changed
- Upgrade `GrottoPress/pond` shard to v2.0

## [0.19.0] - 2024-02-21

### Changed
- Change default task `retries` to `[2, 4, 8, 16]`

## [0.18.1] - 2024-02-14

### Fixed
- Replace `Fiber.yield` with `sleep 1.microsecond` in loops to reduce CPU load

## [0.18.0] - 2023-12-07

### Changed
- Add `from:` parameter to `Mel::Job::Every#run_every` methods
- Add `from:` parameter to `Mel::Job::On#run_on` methods

## [0.17.2] - 2023-12-04

### Fixed
- Skip missed schedules to avoid running tasks multiple times on next schedule

## [0.17.1] - 2023-12-02

### Fixed
- Fix wrong ordering of logs during task run

## [0.17.0] - 2023-12-01

### Added
- Add support for retries with backoffs
- Add jitter to poll interval

### Changed
- Convert `Mel::Task` module to an `abstract class`
- Convert `Mel::RecurringTask` module to an `abstract class`
- Upgrade `jgaskins/redis` shard to v0.8
- Make `Mel::Task#run` method only available to workers
- Remove hyphens from default task IDs (UUIDs)
- Revert default `.poll_interval` to 3 seconds

### Fixed
- Avoid a single task running multiple times if using multiple workers

### Removed
- Remove `Mel::Task::Any` alias

## [0.16.0] - 2023-10-09

### Changed
- Ensure `Mel::Progress::Query#get` methods return the expected type

## [0.15.0] - 2023-09-30

### Fixed
- Fix compile error from query `#get` methods if passed a `redis` argument
- Fix wrong return values from query `#get` methods if passed a `redis` argument

### Changed
- Remove `redis` parameter from all query `#get` methods

## [0.14.0] - 2023-09-29

### Fixed
- Fix compile error when querying with tuple IDs instead of array IDs

### Changed
- Save progress report in redis as JSON-serialized string instead of hash

### Removed
- Remove `Mel::Progress::Report.find` methods

## [0.13.0] - 2023-09-26

### Added
- Add `Mel::Progress::Report#pending?`

### Changed
- Rename `Mel::Progress::Report#moving?` to `#running?`
- Redefine `Mel::Progress::Report#running?` to mean the progress is started and is greater than zero

## [0.12.0] - 2023-09-19

### Added
- Add `Mel::Progress::Report.new(Indexable)` overload

### Changed
- Make task objects externally immutable

### Removed
- Remove `Mel::Job::Template#run`
- Remove `.redis_pool_size` setting

## [0.11.0] - 2023-08-26

### Changed
- Set default `.batch_size` to `-100`
- Increase default `.poll_interval` to 15 seconds

### Fixed
- Fix `Invalid Int32` error when tracking progress

## [0.10.0] - 2023-06-01

### Changed
- Upgrade `GrottoPress/pond` shard to v1.0
- Upgrade `jgaskins/redis` shard to v0.7

### Removed
- Remove `luckyframework/habitat` dependency

## [0.9.1] - 2023-05-02

### Changed
- Use `WORKER_ID` environment variable as default `.worker_id` setting

## [0.9.0] - 2023-03-13

### Added
- Add `.error_handler` setting
- Add `Mel::Progress::Report`

### Changed
- Make `Mel.start_async` methods available outside specs
- Automatically stop *Mel* when program exits
- Return just the task ID (not the whole task) from `Mel::Job.run_*` methods
- Make task objects externally immutable

### Removed
- Remove `Mel::Progress#backward`
- Remove `Mel::Progress#forward`
- Remove `Mel::Progress#failure?`
- Remove `Mel::Progress#moving?`
- Remove `Mel::Progress#success?`
- Remove `Mel::Progress.failure?(Number)`
- Remove `Mel::Progress.moving?(Number)`
- Remove `Mel::Progress.success?(Number)`
- Remove `.rescue_errors` setting

## [0.8.0] - 2023-01-12

### Changed
- Switch to [`luckyframework/habitat`](https://github.com/luckyframework/habitat) for managing configuration
- Make `Mel::State` enum public

### Fixed
- Ensure jobs cannot be mutated in cloned tasks

## [0.7.0] - 2022-11-21

### Added
- Add `Mel::Task::Any` alias
- Add `Mel::Progress.failure?(Number)`
- Add `Mel::Progress.moving?(Number)`
- Add `Mel::Progress.success?(Number)`

### Changed
- Upgrade `jgaskins/redis` shard to v0.6
- Make `Mel::Task#id` and `Mel::Task#job` read-only
- Return the whole task (not just the `id`) from `Mel::Job.run_*` methods

## [0.6.1] - 2022-03-17

### Added
- Ensure support for *Crystal* v1.3.0

### Fixed
- Include only specific data in logs to avoid exposing sensitive data

## [0.6.0] - 2022-01-03

### Added
- Add support for *Crystal* v1.2
- Add `redis_key_prefix` setting
- Add `Mel.start_async(&)` spec helper

### Fixed
- Use `Mutex` when updating worker state

## [0.5.0] - 2021-08-17

### Added
- Add `Mel::Progress#forward` for moving progress forward by a given value.
- Add `Mel::Progress#backward` for moving progress backward by a given value.
- Allow force-scheduling a job
- Add `rescue_errors` setting to optionally rescue exceptions

### Changed
- Enable setting arbitrary schedule for any given schedule template
- Rename `Mel::Progress#track(value)` to `#move`
- Rename `Mel::Progress#tracking?` to `#moving?`

### Removed
- Remove schedule templates `.run_*` macros

## [0.4.0] - 2021-07-20

### Added
- Add progress tracker
- Add `Mel::Job#redis`

### Changed
- Move out worker-specific code into own files (enables `require "mel/worker"`).
- Allow limiting the number of running tasks via the `batch_size` setting

### Removed
- Remove `Mel::Job#run(&)`

### Fixed
- Ensure tasks are never lost in the event of a force shutdown
- Ensure tasks run even if any callback raises an exception

## [0.3.0] - 2021-06-16

### Added
- Add spec helpers
- Add support for [*Carbon*](https://github.com/luckyframework/carbon) mailer
- Add schedule templates

### Fixed
- Ensure running tasks complete if *Mel* stopped in main fiber

## [0.2.0] - 2021-05-03

### Added
- Add support for bulk scheduling
- Add per task `retries` argument.

### Changed
- Return `nil` for query methods returning empty collections
- Pass status as argument to `after_*` callbacks.

### Fixed
- Ensure interval specified for periodic tasks cannot be negative
- Fix log settings not working

## [0.1.0] - 2021-04-06

### Added
- Initial public release
