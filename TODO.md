# TODO

## Aggregate queries

* AggregateReport inherits from Report.
* Stores subset of columns for SELECT (& GROUP) fields.
* Stores subset of columns for aggregation and each type (SUM, AVG, MIN, MAX, COUNT).
* Optionally stores subset of columns for ORDER fields.
* Report cannot already have `GROUP BY` present. (?)
* Get SQL string of query modified ready for aggrgate modifications.
    * Convert `SELECT... ` to `SELECT *`.
    * Add `GROUP BY 1stcolumn`.
    * If there is an `ORDER BY`, convert to `ORDER BY 1stcolumn`.
    * DEPARSE to String.
    * Modify String.
        * Replace `SELECT *` with `SELECT $1`.
        * Replace `GROUP BY 1stcolumn` with `GROUP BY $2`.
        * Replace `ORDER BY 1stcolumn` with `ORDER BY $3` if there.
        * Add `ORDER BY $3` if not there.
* Replace Strings with columns.
    * $1 replaced by SELECT columns and aggregate columns. (SELECT columns include aliases)
    * $2 replaced by SELECT columns. (No aliases)
    * $3 replaced by required ORDER columns if there are any.
    * `ORDER BY $3` line removed if there are no ORDER columns.
* Parse resulting SQL String.
* Apply WHERE clause to newly-parsed query in same way as for Report.
* Deparse query and return Aggregate Query SQL String.

## Where clause

* Group QueryParameters.
    * Several values of the same fields - IN clause.
    * Several values of the same fields - bracketed OR clause.
    * Several values of diferent fields -  bracketed OR clause.

