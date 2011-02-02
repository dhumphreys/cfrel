<cfcomponent extends="tests.TestCase" output="false">
	
	<!--- TODO: Improve testing. Verify SQL trees instead of visit() return value. Improve comments --->
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "cfrel.Relation";
			variables.datasourceRel = new(datasource="cfrel").select("id,username,password").from("users");
			variables.sqlVisitor = CreateObject("component", "cfrel.visitors.Sql").init();
		</cfscript>
	</cffunction>
	
	<cffunction name="visit" returntype="any" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfreturn variables.sqlVisitor.visit(arguments.obj) />
	</cffunction>
	
	<cffunction name="testInit" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// init and count public variables
			loc.obj = new(init=false);
			loc.varCount1 = StructCount(loc.obj);
			loc.instance = loc.obj.init();
			loc.varCount2 = StructCount(loc.instance);
			
			// make sure init modifies instance, not creating a new one
			assertIsTypeOf(loc.instance, "cfrel.Relation");
			assertSame(loc.obj, loc.instance, "init() should return same instance");
			assertTrue(loc.varCount2 GT loc.varCount1, "init() should define private variables");
		</cfscript>
	</cffunction>
	
	<cffunction name="testInitWithOptions" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// create a new item with some options
			loc.instance = new(init=false).init(datasource="test", visitor="MSSql");
			
			// make sure datasource and visitor were correctly set
			assertEquals("test", loc.instance.datasource, "Datasource should be set through constructor");
			assertIsTypeOf(loc.instance.visitor, "cfrel.visitors.MSSql");
		</cfscript>
	</cffunction>
	
	<cffunction name="testNew" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.factory = new(init=false);
			loc.instance = loc.factory.new();
			assertIsTypeOf(loc.instance, "cfrel.Relation");
			assertNotSame(loc.instance, loc.factory, "new() should create a new instance");
		</cfscript>
	</cffunction>
	
	<cffunction name="testClone" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new(datasource="cfrel");
			loc.clone1 = injectInspector(loc.instance.clone());
			loc.clone1.select("id").from("users").exec();
			loc.clone2 = injectInspector(loc.clone1.clone());
			
			// get private scopes
			loc.private1 = loc.clone1._inspect();
			loc.private2 = loc.clone2._inspect();
			
			// make sure that call returns a different relation object
			assertIsTypeOf(loc.clone1, "cfrel.Relation");
			assertNotSame(loc.clone1, loc.instance, "clone() should return copy of object, not same one");
			assertNotSame(loc.clone1, loc.clone2);
			assertNotSame(loc.clone1.sql, loc.instance.sql, "clone() should copy the sql struct, not reference it");
			assertNotSame(loc.clone1.sql, loc.clone2.sql);
			assertEquals(loc.clone1.datasource, loc.clone2.datasource);
			assertTrue(IsQuery(loc.private1.query));
			assertFalse(loc.private2.query);
		</cfscript>
	</cffunction>
	
	<cffunction name="testAutoClone" returntype="void" access="public">
		<cfscript>
			var instance = datasourceRel.clone().exec();
			var key = "";
			var loc = {};
			
			// call each of the basic chainable methods
			loc.select = instance.select("a");
			loc.distinct = instance.distinct();
			loc.from = instance.from("users");
			loc.join = instance.join("posts", "post_user_id = user_id");
			loc.group = instance.group("a");
			loc.having = instance.having("a > ?", [0]);
			loc.order = instance.order("a ASC");
			loc.limit = instance.limit(5);
			loc.offset = instance.offset(10);
			loc.paginate = instance.paginate(1, 5);
			
			// assert that each return is not the original object and has an empty query
			for (key in loc) {
				injectInspector(loc[key]);
				assertNotSame(instance, loc[key], "Operation #key#() should auto-clone");
				assertFalse(loc[key]._inspect().query);
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="testCallsAreChainable" returntype="void" access="public">
		<cfscript>
			var instance = new();
			var key = "";
			var loc = {};
			
			// call each of the basic chainable methods
			loc.select = instance.select("a");
			loc.distinct = instance.distinct();
			loc.from = instance.from("users");
			loc.join = instance.join("posts", "post_user_id = user_id");
			loc.where = instance.where(a=5);
			loc.group = instance.group("a");
			loc.having = instance.having("a > ?", [0]);
			loc.order = instance.order("a ASC");
			loc.limit = instance.limit(5);
			loc.offset = instance.offset(10);
			loc.paginate = instance.paginate(1, 5);
			
			// chain each call together for further testing
			loc.multiple = instance.select("b").distinct().from("posts").join("authors", "post_id = author_id").where(b=10).group("b").having("b >= 10").order("b DESC").limit(2).offset(8).paginate(3, 10);
			
			// assert that each return is still the same object
			for (key in loc)
				assertSame(instance, loc[key]);
		</cfscript>
	</cffunction>
	
	<cffunction name="testSelectSyntax" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.testVal = ListToArray("a,b,c");
			
			// run SELECT in various ways
			loc.instance1 = new().select("*");
			loc.instance2 = new().select("a,b,c");
			loc.instance3 = new().select("a","b","c");
			
			// make sure nodes were added and evaluate to input strings
			assertIsTypeOf(loc.instance1.sql.select[1], "cfrel.nodes.Wildcard");
			assertIsTypeOf(loc.instance2.sql.select[1], "cfrel.nodes.Column");
			assertIsTypeOf(loc.instance2.sql.select[2], "cfrel.nodes.Column");
			assertIsTypeOf(loc.instance2.sql.select[3], "cfrel.nodes.Column");
			assertIsTypeOf(loc.instance3.sql.select[1], "cfrel.nodes.Column");
			assertIsTypeOf(loc.instance3.sql.select[2], "cfrel.nodes.Column");
			assertIsTypeOf(loc.instance3.sql.select[3], "cfrel.nodes.Column");
			assertEquals(["*"], visit(loc.instance1.sql.select));
			assertEquals(loc.testVal, visit(loc.instance2.sql.select));
			assertEquals(loc.testVal, visit(loc.instance3.sql.select));
		</cfscript>
	</cffunction>
	
	<cffunction name="testSelectAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// run chained selects to confirm appending with both syntaxes
			loc.instance = new().select("a,b").select("c","d").select("e,f");
			
			// make sure items were stacked/appended
			assertEquals(ListToArray("a,b,c,d,e,f"), visit(loc.instance.sql.select), "SELECT should append additional selects");
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptySelect" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.instance = new();
			
			// confirm that exception is thrown
			try {
				loc.instance.select();
			} catch (custom_type e) {
				loc.pass = true;
			}
			
			assertTrue(loc.pass, "Empty parameters to SELECT should throw an error");
		</cfscript>
	</cffunction>
	
	<cffunction name="testDistinct" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().distinct().distinct(); // yes, call twice
			assertEquals("DISTINCT", loc.instance.sql.selectFlags[1], "distinct() should set DISTINCT flag");
			assertEquals(1, ArrayLen(loc.instance.sql.selectFlags), "DISTINCT should only be set once");
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptyFrom" returntype="void" access="public">
		<cfscript>
			assertFalse(StructKeyExists(new().sql, "from"), "FROM clause should not be set initially");
		</cfscript>
	</cffunction>
	
	<cffunction name="testFromWithString" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().from("users");
			assertEquals("users", loc.instance.sql.from.table, "FROM clause should be set to passed value");
		</cfscript>
	</cffunction>
	
	<cffunction name="testFromWithRelation" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new();
			loc.instance2 = new().from(loc.instance);
			assertSame(loc.instance, loc.instance2.sql.from, "FROM clause should be set to passed relation");
		</cfscript>
	</cffunction>
	
	<cffunction name="testFromWithQuery" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.query = QueryNew('');
			loc.instance = new();
			loc.private = loc.instance._inspect();
			assertFalse(loc.private.qoq, "QOQ should be false initially");
			loc.instance.from(loc.query);
			assertSame(loc.query, loc.instance.sql.from, "FROM clause should be set to passed query");
			assertTrue(loc.private.qoq, "QOQ should be true after using from(query)");
		</cfscript>
	</cffunction>
	
	<cffunction name="testFromWithInvalidObject" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			try {
				new().from(StructNew());
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertTrue(loc.pass, "from() should throw exception when given invalid object");
		</cfscript>
	</cffunction>
	
	<cffunction name="testSingleWhere" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().where("1 = 1");
			assertEquals(1, ArrayLen(loc.instance.sql.wheres));
			assertEquals(0, ArrayLen(loc.instance.sql.whereParameters));
			assertIsTypeOf(loc.instance.sql.wheres[1], "cfrel.nodes.BinaryOp");
			assertEquals("1 = 1", visit(loc.instance.sql.wheres[1]));
		</cfscript>
	</cffunction>
	
	<cffunction name="testAppendWhere" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().where("1 = 1").where("2 = 2");
			assertEquals("1 = 1", visit(loc.instance.sql.wheres[1]));
			assertEquals("2 = 2", visit(loc.instance.sql.wheres[2]));
		</cfscript>
	</cffunction>
	
	<cffunction name="testWhereWithParameters" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.whereClause = "id = ? OR name = '?' OR role IN (?)";
			loc.whereParameters = [50, "admin", [1,2,3]];
			loc.instance = new().where(loc.whereClause, loc.whereParameters);
			assertEquals(loc.whereClause, visit(loc.instance.sql.wheres[1]), "where() should set the passed condition");
			assertEquals(loc.whereParameters, visit(loc.instance.sql.whereParameters), "where() should set parameters in correct order");
		</cfscript>
	</cffunction>
	
	<cffunction name="testWhereParameterCount" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.instance = new();
			try {
				loc.instance.where("id = ? OR name = '?'", [2]);
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertTrue(loc.pass, "where() should throw an error if wrong count of parameters is passed");
		</cfscript>
	</cffunction>
	
	<cffunction name="testWhereWithNamedArguments" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().where(a=45, b="BBB", c=[1,2,3]);
			assertEquals(["a = ?", "b = ?", "c IN (?)"], visit(loc.instance.sql.wheres), "Named arguments should be in WHERE clause");
			assertEquals([45, "BBB", [1,2,3]], loc.instance.sql.whereParameters, "Parameters should be set and in correct order");
		</cfscript>
	</cffunction>
	
	<cffunction name="testGroupSyntax" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.testVal = ListToArray("a,b,c");
			
			// run GROUP in various ways
			loc.instance1 = new().group("a,b,c");
			loc.instance2 = new().group("a","b","c");
			
			// make sure the items were added
			assertEquals(loc.testVal, visit(loc.instance1.sql.groups));
			assertEquals(loc.testVal, visit(loc.instance2.sql.groups));
		</cfscript>
	</cffunction>
	
	<cffunction name="testGroupAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// run chained groups to confirm appending with both syntaxes
			loc.instance = new().group("a,b").group("c","d").group("e,f");
			
			// make sure items were stacked/appended
			assertEquals(ListToArray("a,b,c,d,e,f"), visit(loc.instance.sql.groups));
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptyGroup" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.instance = new();
			
			// confirm that exception is thrown
			try {
				loc.instance.group();
			} catch (custom_type e) {
				loc.pass = true;
			}
			
			assertTrue(loc.pass, "Empty parameters to GROUP should throw an error");
		</cfscript>
	</cffunction>
	
	<cffunction name="testSingleHaving" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().having("a > 1");
			assertEquals(1, ArrayLen(loc.instance.sql.havings));
			assertEquals(0, ArrayLen(loc.instance.sql.havingParameters));
			assertIsTypeOf(loc.instance.sql.havings[1], "cfrel.nodes.BinaryOp");
			assertEquals("a > 1", visit(loc.instance.sql.havings[1]));
		</cfscript>
	</cffunction>
	
	<cffunction name="testAppendHaving" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().having("a > 1").having("b < 0");
			assertIsTypeOf(loc.instance.sql.havings[2], "cfrel.nodes.BinaryOp");
			assertEquals("b < 0", sqlVisitor.visit(loc.instance.sql.havings[2]), "having() should append the second condition");
		</cfscript>
	</cffunction>
	
	<cffunction name="testHavingWithParameters" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.havingClause = "id = ? OR name = '?' OR role IN (?)";
			loc.havingParameters = [50, "admin", [1,2,3]];
			loc.instance = new().having(loc.havingClause, loc.havingParameters);
			assertEquals(loc.havingClause, visit(loc.instance.sql.havings[1]), "having() should set the passed condition");
			assertEquals(loc.havingParameters, visit(loc.instance.sql.havingParameters), "having() should set parameters in correct order");
		</cfscript>
	</cffunction>
	
	<cffunction name="testHavingParameterCount" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.instance = new();
			try {
				loc.instance.having("id = ? OR name = '?'", [2]);
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertTrue(loc.pass, "having() should throw an error if wrong count of parameters is passed");
		</cfscript>
	</cffunction>
	
	<cffunction name="testHavingWithNamedArguments" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().having(a=45, b="BBB", c=[1,2,3]);
			assertEquals(["a = ?", "b = ?", "c IN (?)"], visit(loc.instance.sql.havings), "Named arguments should be in HAVING clause");
			assertEquals([45, "BBB", [1,2,3]], loc.instance.sql.havingParameters, "Parameters should be set and in correct order");
		</cfscript>
	</cffunction>
	
	<cffunction name="testOrderSyntax" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.testVal = ListToArray("a ASC,b DESC,c ASC");
			
			// run ORDER in various ways
			loc.instance1 = new().order("a ASC,b DESC,c");
			loc.instance2 = new().order("a ASC","b DESC","c");
			
			// make sure the items were added
			assertEquals(loc.testVal, visit(loc.instance1.sql.orders), "ORDER BY clause should accept a list of columns");
			assertEquals(loc.testVal, visit(loc.instance2.sql.orders), "ORDER BY clause should accept a columns as multiple arguments");
		</cfscript>
	</cffunction>
	
	<cffunction name="testOrderAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// run chained orders to confirm appending with both syntaxes
			loc.instance = new().order("a,b").order("c","d").order("e,f");
			
			// make sure items were stacked/appended
			assertEquals(ListToArray("a ASC,b ASC,c ASC,d ASC,e ASC,f ASC"), visit(loc.instance.sql.orders));
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptyOrder" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.instance = new();
			
			// confirm that exception is thrown
			try {
				loc.instance.order();
			} catch (custom_type e) {
				loc.pass = true;
			}
			
			assertTrue(loc.pass, "Empty parameters to ORDER should throw an error");
		</cfscript>
	</cffunction>
	
	<cffunction name="testLimit" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().limit(31);
			assertTrue(StructKeyExists(loc.instance.sql, "limit"), "LIMIT should be set in SQL");
			assertEquals(31, loc.instance.sql.limit, "LIMIT should be equal to value set");
		</cfscript>
	</cffunction>
	
	<cffunction name="testOffset" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().offset(15);
			assertTrue(StructKeyExists(loc.instance.sql, "offset"), "OFFSET should be set in SQL");
			assertEquals(15, loc.instance.sql.offset, "OFFSET should be equal to value set");
		</cfscript>
	</cffunction>
	
	<cffunction name="testPaginateSyntax" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// an example: 5th page of 10 per page
			loc.instance = new().paginate(5, 10);
			
			// make sure proper values were set in LIMIT and OFFSET clauses
			assertTrue(StructKeyExists(loc.instance.sql, "limit"), "LIMIT should be set in SQL");
			assertTrue(StructKeyExists(loc.instance.sql, "offset"), "OFFSET should be set in SQL");
			assertEquals(10, loc.instance.sql.limit, "LIMIT should be equal to value set");
			assertEquals(40, loc.instance.sql.offset, "OFFSET should equal (page - 1) * per-page");
		</cfscript>
	</cffunction>
	
	<cffunction name="testPaginateBounds" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new();
			loc.pass1 = false;
			loc.pass2 = false;
			
			// test <1 value for page
			try {
				loc.instance.paginate(0, 5);
			} catch (custom_type e) {
				loc.pass1 = true;
			}
			
			// test <1 value for perPage
			try {
				loc.instance.paginate(1, 0);
			} catch (custom_type e) {
				loc.pass2 = true;
			}
			
			// make sure errors are thrown
			assertTrue(loc.pass1, "paginate() should throw error when page < 1");
			assertTrue(loc.pass1, "paginate() should throw error when perPage < 1");
		</cfscript>
	</cffunction>
	
	<cffunction name="testSqlGeneration" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = CreateObject("component", "cfrel.visitors.Sql").init();
			
			// generate a simple relation
			loc.instance = new().select("a").from("b").where("a > 5").order("a ASC").paginate(2, 15);
			
			// make sure visitor is being called
			assertEquals(loc.visitor.visit(loc.instance), loc.instance.toSql(), "toSql() should be calling Sql visitor for SQL generation");
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptyDatasource" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.rel = new().select(1);
			try {
				loc.rel.query();
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertEquals("", loc.rel.datasource, "Datasource should be blank");
			assertTrue(loc.pass, "Exception should be thrown if query() is called with empty datasource");
		</cfscript>
	</cffunction>
	
	<cffunction name="testQuery" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = injectInspector(datasourceRel.clone());
			loc.variables = loc.rel._inspect();
			loc.query1 = loc.rel.query();
			loc.query0 = loc.variables.query;
			loc.query2 = loc.rel.query();
			assertTrue(loc.variables.executed, "Calling query() should set executed flag");
			assertTrue(IsQuery(loc.query1), "query() should return a recordset");
			assertSame(loc.query0, loc.query1, "query() should store query inside of the relation");
			assertSame(loc.query1, loc.query2, "Multiple calls to query() should return same recordset object");
		</cfscript>
	</cffunction>
	
	<cffunction name="testResult" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = injectInspector(datasourceRel.clone());
			loc.variables = loc.rel._inspect();
			loc.result1 = loc.rel.result();
			loc.result0 = loc.variables.result;
			loc.result2 = loc.rel.result();
			assertTrue(IsStruct(loc.result1), "result() should return query result data");
			assertSame(loc.result0, loc.result1, "result() should store result inside of the relation");
			assertSame(loc.result1, loc.result2, "Multiple calls to result() should return same result struct");
		</cfscript>
	</cffunction>
	
	<cffunction name="testExecution" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = injectInspector(datasourceRel.clone()).exec();
			loc.variables = loc.rel._inspect();
			loc.query1 = loc.variables.query;
			assertTrue(IsQuery(loc.query1), "Execute should populate query field");
			loc.query2 = loc.rel.query();
			assertSame(loc.query1, loc.query2, "exec() should run and store the query for calls to query()");
		</cfscript>
	</cffunction>
	
	<cffunction name="testReload" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = injectInspector(datasourceRel.clone());
			loc.query1 = loc.rel.query();
			loc.query2 = loc.rel.reload().query();
			assertTrue(IsQuery(loc.query2), "A query object should be returned");
			assertNotSame(loc.query1, loc.query2, "reload() should cause a new query to be executed");
		</cfscript>
	</cffunction>
	
	<cffunction name="testQueryOfQuery" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = datasourceRel.clone();
			loc.query = loc.rel.query();
			loc.qoq1 = loc.rel.qoq();
			loc.qoq2 = loc.rel.where("1 = 1");
			assertNotSame(loc.rel, loc.qoq1);
			assertNotSame(loc.qoq1, loc.qoq2);
			assertSame(loc.query, loc.qoq1.sql.from);
			assertSame(loc.query, loc.qoq2.sql.from);
		</cfscript>
	</cffunction>
</cfcomponent>