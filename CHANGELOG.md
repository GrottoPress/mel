# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased] - 

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
