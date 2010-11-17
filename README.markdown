# CFRel

## Purpose

To develop a ColdFusion engine for turning chained method calls into SQL statements through relational algebra

## Current Features

* Object-oriented, chainable syntax for creating queries
* SELECT, FROM, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT, and OFFSET
* Specifying another relation as the subject of FROM
* Generating of generic SQL based on contents of relation
* Testing suite provided by MXUnit

## Example

Here is an example of the functionality currently available in CFRel:

	<cfscript>
		rel = CreateComponent("component", "cfrel.relation").init()
			.select("a,b,c,SUM(d)")
			.from("tableA")
			.where("a = ? AND b = ?", [23, 45])
			.where(c=[1,2,3,4])
			.group("a,b,c")
			.having("SUM(d) > ?", [0])
			.order("a ASC")
			.paginate(5, 10);
		
		writeOutput(rel.toSql());
		
		/*
		SELECT a, b, c, SUM(d) FROM tableA
		WHERE a = ? AND b = ? AND c IN (?, ?, ?, ?)
		GROUP BY a, b, c
		HAVING SUM(d) > ?
		ORDER BY a ASC
		LIMIT 10 OFFSET 40
		*/
	</cfscript>

## Features In Progress

* Execution directly against the database
* JOIN and UNION support in queries
* Database-specific SQL generation: Sqlite, Sql Server, MySql, DB2, etc...
* Intelligent table / column mapping, escaping, and aliasing
* SQL literal objects that pass raw SQL code
* Query-of-Query support when FROM is a ColdFusion query object
* Automatic use of Query-of-Query when filtering a relation that has already been executed
* Joining across databases using Query-of-Query and WHERE logic
* More abstraction of portions of the SELECT clause
* Full ColdFusion 9 / Railo 3.1 support
* Plugin integration into CFWheels