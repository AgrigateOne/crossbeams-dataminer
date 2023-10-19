# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres roughly to [Semantic Versioning](http://semver.org/).


## [Unreleased]
### Added
- Column attribute `funcname` holds the name of the function call (if any). e.g. `sum`
- Column method `aggregate_function?` returns true if the column is a sum, count, min, max or avg aggregate
- Report method `summarised_query?` returns true if the report has a GROUP BY clause
- Report method `non_aggregate_columns` returns an array of columns that are not aggregates
- Report method `aggregate_columns` returns an array of columns that are aggregates
- Report method `change_column_selection` takes arrays of non-aggregate and aggregate columns and removes any not included from the report's columns list and the group by clause
- Report sets the `summarised` attribute when represented in a hash
### Changed
### Fixed

## [2.1.0] - 2022-11-03
### Changed
- Upgrade `pg_query` to version 2.2.0

## [2.0.0] - 2022-10-27
### Added
- New operator `in_or_null`. Will resolve to `(col IN (values) OR col IS NULL)`. IF there are no values provided, it will resolve to `col IS NULL`.
### Changed
- Upgrade to Ruby 3
### Fixed
- Loading a persisted report will ignore any extra columns

## [1.0.0] - 2022-09-21
### Changed
- Upgrade `pg_query` to version 2.1.4
- Change `RuntimeException`s to `Crossbeams::Dataminer::Error`s.
- `YamlPersistor` now stores the SQL key's value as a YAML literal (starting with `|` char) instead of a quoted string. This makes file diffing easier.

## [0.2.1] - 2021-08-25
### Added
- New operator `match_or_null`. Will resolve to `(col = value OR col IS NULL)`.
### Changed
- SQL with duplicate columns now specifies the column name.
- parameter with IN operator can receive an empty array. The condition effectively becomes false (1 = 2).

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
