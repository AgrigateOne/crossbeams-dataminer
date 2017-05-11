<!-- Tocer[start]: Auto-generated, don't remove. -->

# Table of Contents

- [TODO](#todo)
  - [Aggregate queries](#aggregate-queries)
  - [Where clause](#where-clause)
  - [Join pruning](#join-pruning)

<!-- Tocer[finish]: Auto-generated, don't remove. -->

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

SELECT id, invoice_ref_no, customer_id, voyage_id, currency_id, invoice_date, completed, approved, cancelled FROM invoices
--WHERE id > 3 AND NOT approved
--WHERE id > 3 AND (cancelled OR NOT completed)
--WHERE customer_id = 123 OR voyage_id = 221
WHERE id IN (5,6,7,8,9,10,11,12)

## Join pruning

With the use of view I recently had an uncomfortable feeling that queries can be done more simplistic, but did not know how to prove that. In Kromco's database we have views like vwcartons that join on tables which is not always necessary because the selected fields do not require it. These views are created as a "catch all" type of solution. Luckily Postgresql Optimizer/Planner can do join pruning. Unfortunately the planner/optimizer can also make mistakes.

I realize this today while working with Jaspersoft's Adhoc query Tool which construct the sql statement by analyzing the fields which is used in a report and eliminate the join if the fields from that table is not used. 

When i realize this I did some more test by changing inner joins to left join on fields which have the necessary foreign keys, this it fact did gave me on certain instances a 300% saving. By using left joins allowed the Optimizer/Planner to prune the joins, but it did not do it accurately on all instances. Which bring me to the point/question, do our dataminer do join construction/pruning?

> If I understand you correctly, you would want functionality to remove a join from the SQL you provide when creating a yml report if there are no columns returned from that table?
> i.e. functionality similar to what you describe from Jasper?


Yes, that is what i am after. I hope we can implement those type of new framework improvements in a modular fashion?


