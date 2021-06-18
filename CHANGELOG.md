# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased] - 

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
