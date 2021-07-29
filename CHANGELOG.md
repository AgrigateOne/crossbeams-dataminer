# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres roughly to [Semantic Versioning](http://semver.org/).


## [Unreleased]
### Added
### Changed
- SQL with duplicate columns now specifies the column name.
- parameter with IN operator can receive an empty array. The condition effectively becomes false (1 = 2).
### Fixed

## [0.2.0] - 2019-10-07
### Changed
- Upgrade PgQuery gem from 1.0.2 to 1.1.0.

## [0.1.8] - 2019-08-31
### Added
- A new method `case_string_values` on Column to get a list of string values from a `CASE` expression.

## [0.1.7] - 2019-06-19
### Added
- `ordered_query_parameter_definitions` method for Reports. Returns parameter definitions ordered first by UI priority, then by caption.

## [0.1.6] - 2019-01-08
### Added
- New method `parameter_texts` for Report to display selected parameters in an array of human-readable strings.
- New Column attribute `pinned`. Can be 'left' or 'right' or nil.
### Fixed
- Raise an exception if the SQL used for a QueryParameterDefinition `list_def` is not a SELECT.

## [0.1.5] - 2018-07-08
### Added
- "runnable_sql_delimited" method wraps "runable_sql" method. For :mssql will strip out double quote identifiers.
- "runnable_sql_delimited" converts a LIMIT clause to a TOP clause for :mssql.
- "runnable_sql_delimited" will raise a Syntax error for :mssql queries that contain an OFFSET clause.
- New report method "tables_or_aliases". Returns all tables used in the query, but returns an alias when that is used instead of a table.
  Note that this will not return the table name if a table is used twice - once with an alias and once witout.

## [0.1.4] - 2018-04-11
### Changed
- Upgrade PgQuery gem to 1.0.2.

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
