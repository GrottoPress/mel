# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased] - 

### Added
- Add support for bulk scheduling
- Add per task `retries` argument.

### Changed
- Return `nil` for query methods returning empty collections
- Pass status as argument to `after_*` callbacks.

### Fixed
- Ensure interval specified for periodic tasks cannot be negative

## [0.1.0] - 2021-04-06

### Added
- Initial public release
