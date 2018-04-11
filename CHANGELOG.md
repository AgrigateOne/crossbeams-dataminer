# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres roughly to [Semantic Versioning](http://semver.org/).


## [Unreleased]
### Added
### Changed
Upgrade PgQuery gem to 1.0.2.
### Fixed

## [0.1.3] - 2018-04-03
### Added
- Reports can be saved with external settings (a Hash). This allows users of the gem to store settings pertinent to the usage of the report (i.e. not to do with the design itself). For example, store an override url to be used when rendering.

## [0.1.2] - 2018-02-09
### Added
- This changelog.
### Fixed
- Report changed to handle PGQuery change in parsetree structure introduced with the release of pg_query 1.0.0.

## [0.1.1] - 2018-02-08
### Changed
- Upgrade to Ruby 2.5.
- Start to use git flow for releases.
