# CFRel

## Purpose

To develop a ColdFusion engine for turning chained method calls into SQL statements through relational algebra

### Current Features

* Object-oriented, chainable syntax for creating queries
* SELECT, FROM, JOIN, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT, and OFFSET
* Specifying another relation as the subject of FROM
* Query-of-Query support when FROM is a ColdFusion query object
* Parsing of programmer input into complex node trees
* Generating of generic SQL based on node tree
* SQL generation specific to following DBMS
  * Microsoft Sql Server
* Automatic use of Query-of-Query when filtering a relation that has already been executed
* SQL literal objects that pass raw SQL code into queries
* Execution directly against a datasource
* Testing suite provided by MXUnit
* Plugin integration for CFWheels
  * Replaces existing findAll() model function
  * Adds select(), where(), and other functions to models
  * Intelligent table / column mapping and aliasing
  * "Include" support that creates JOINs identical to CFWheels
  * https://github.com/dhumphreys/cfwheels-cfrel

### Features In Progress

* Full ColdFusion 9 / Railo 3.1 compatibility
* Database-specific SQL generation for: Sqlite, MySql, DB2, etc...
* Escaping of table/column identifiers
* More abstraction of SQL tree
* Joining across datasources using Query-of-Query and WHERE logic
* UNION support in queries

## The Basics

The most basic CFRel query only requires a SELECT or FROM: 

	<cfscript>
	
		// construct a basic, empty relation
		empty_rel = relation();
		
		// a fully structured relation, but not ran against the database yet
		rel = relation().select("a,b,c").from("t");
	
		// SELECT * FROM users
		table_data = relation(datasource="cfrel").from("users").query();
		
		// SELECT 1, 2, 3
		just_data = relation(datasource="cfrel").select(1, 2, 3).query();
		
	</cfscript>

Each method call on a relation builds an internal SQL tree that is converted into a query string right before execution. Here is a list of the methods currently available in CFRel:

### Construction Methods

* relation([database], [visitor])
* select(fieldList)
* select(field1, [field2, ..., fieldN])
* distinct()
* from(tableName)
* from(relation)
* from(queryObject)
* join(tableName, condition, conditionParams, type)
* include(includeString)
* where(whereClause, [arrayOfParams])
* where(col1=value, col2=value, ..., colN=value)
* group(fieldList)
* group(field1, [field2, .., fieldN])
* having(havingClause, [arrayOfParams])
* having(col1=value, col2=value, ..., colN=value)
* order(order_list)
* order(order1, [order2, ..., orderN])
* limit(numberOfRows)
* offset(numberOfRows)

### Execution Methods

* sql()
* exec()
* query()
* result()
* reload()

### Relation Splitting

* clone()
* qoq()

### Pagination

Using the paginate() method is the same as intelligently setting LIMIT and OFFSET to control paging, only using page number and size instead.

* paginate(pageNumber, rowsPerPage)

	<cfscript>
		
		// SQL: SELECT a, b, c FROM t ORDER BY a ASC LIMIT 20 OFFSET 100
		rel = relation().select("a,b,c").from("t").order("a ASC").paginate(6, 20);
		sql = rel.toSql();
		
	</cfscript>

### Chaining

Complex queries can be made by chaining calls. All of the methods above return the Relation object they are invoked on, therefore allowing multiple calls to select(), where() and the like in a single line of code. Except for limit(), offset() and paginate(), all of the calls simply append their arguments instead of replacing them. This means they can be called multiple times to only use some parts of query under certain conditions.

	<cfscript>
	
		/*
		SQL: SELECT id, name, qty FROM products WHERE qty BETWEEN ? AND ?
		      ORDER BY qty DESC LIMIT 10 OFFSET 40
		PARAMS: [5, 10]
		*/
		rel1 = relation(datasource="cfrel")
			.select("id,name,qty").from("products")
			.where("qty BETWEEN ? AND ?", [5, 10])
			.order("qty DESC")
			.limit(10).offset(40);
		query1 = rel1.query(); 
		
		/*	
		SQL: SELECT productId, SUM(total) AS totalSum FROM orders
		     GROUP BY productId HAVING SUM(total) > ?
		     ORDER BY totalSum DESC LIMIT 5
		PARAMS: [1000]
		*/
		rel2 = relation(datasource="cfrel")
			.select("productId,SUM(total) AS totalSum")
			.from("orders")
			.group("productId")
			.having("SUM(total) > ?", [1000])
			.order("totalSum DESC")
			.limit(5);
		query2 = rel2.query();
		
		/*
		SQL: SELECT a, b, c, d FROM t WHERE (a = ? OR a = ?) AND c = ? AND d = ?
		PARAMS: [100, 200, 0, 0]
		*/
		rel3 = relation(datasource="cfrel")
			.select("a", "b").select("c,d")
			.from("t")
			.where("a = ? OR a = ?", [100, 200])
			.where(c=0, d=0);
		query3 = rel3.query();
		
	</cfscript>

### Query Execution and Lazy Loading

A relation is not turned into SQL and executed until explicitly told to do so. There are several ways to tell a relation to execute against the database, all of which take advantage of lazy loading.

	<cfscript>
	
		// run the query, if not already ran, and return the recordset object
		query1 = rel1.query();
		
		// return the same query object fetched from above
		query2 = rel1.query();
		
		// get the result structure of the query, executing it if necessary
		results = rel2.results();
		
		// execute the query if not already ran, but chain the relation to allow additional calls
		rel3.exec();
		
		// force reloading of the query, and chain the relation
		rel1.reload();
		
	</cfscript>

Above, query1 and query2 will refer to the same recordset, and query3 will be a new hit on the database.

## Advanced Usage

### Cloning and Query-of-Queries

Using the clone() method allows for the SQL tree of a relation to be duplicated into a new relation, and then further modified. All data and references specific to the original relation are not copied. There are some cases where relations auto-clone, such as when a select() or group() is called on a relation that has already loaded data.

	<cfscript>
	
		// creates a clone of rel1 that can have more SQL added to it
		rel1 = relation().select("first_col").from("some_table");
		rel2 = rel1.clone().select("another_col").where("another_col < ?", [30]);
		
		// another example, but with auto-cloning. rel2 will be a different object than rel1
		rel1 = relation().select("a,b").from("alphabet_table");
		query1 = rel1.query();
		rel2 = rel1.select("c").limit(10);
		
	</cfscript>
	
Similarly, calling qoq() will lazily execute the query and return a new relation. The new relation will have the recordset itself as the FROM clause, causing a query-of-query to be performed. Calling where() on a relation that has already been executed automatically creates a QOQ relation.

	<cfscript>
		
		// forces execution of query, and creates a new relation that queries the resultset in memory
		rel1 = relation().select("a, b").from("t");
		rel2 = rel1.qoq().where("b = ?", [5]);
		
		// here we get the same result, but automatically call qoq() when where() is called
		rel1 = relation().select("a, b").from("t").exec();
		rel2 = rel1.where("b = ?", [5]);
		
	</cfscript>

The key on auto-cloning and auto-qoq is that they happen when a relation has already been executed.

### Sub-Queries / Nested Relations

Relations can also be nested within each other to create deep queries with minimal effort.

	<cfscript>
	
		// create a basic relation
		rel1 = relation().select("a,b,c").from("t");
		
		// create a new relation, passing the first one as the FROM clause
		// SELECT * FROM (SELECT a, b, c FROM t) ORDER a DESC LIMIT 50
		rel2 = relation().from(rel1).order("a DESC").limit(50);
		
	</cfscript>