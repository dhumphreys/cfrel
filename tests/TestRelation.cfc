<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "cfrel.relation";
		</cfscript>
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
			assertIsTypeOf(loc.instance, "cfrel.relation");
			assertSame(loc.obj, loc.instance, "init() should return same instance");
			assertTrue(loc.varCount2 GT loc.varCount1, "init() should define private variables");
		</cfscript>
	</cffunction>
	
	<cffunction name="testNew" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.factory = new(init=false);
			loc.instance = loc.factory.new();
			assertIsTypeOf(loc.instance, "cfrel.relation");
			assertNotSame(loc.instance, loc.factory, "new() should create a new instance");
		</cfscript>
	</cffunction>
	
	<cffunction name="testClone" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new();
			loc.clone = loc.instance.clone();
			
			// make sure that call returns a different relation object
			assertIsTypeOf(loc.clone, "cfrel.relation");
			assertNotSame(loc.clone, loc.instance, "clone() should return copy of object, not same one");
			assertNotSame(loc.clone.sql, loc.instance.sql, "clone() should copy the sql struct, not reference it");
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
			loc.include = instance.include();
			loc.join = instance.join();
			loc.where = instance.where(a=5);
			loc.group = instance.group("a");
			loc.having = instance.having("a > ?", [0]);
			loc.order = instance.order("a ASC");
			loc.limit = instance.limit(5);
			loc.offset = instance.offset(10);
			loc.paginate = instance.paginate(1, 5);
			
			// chain each call together for further testing
			loc.multiple = instance.select("b").distinct().from("posts").include().join().where(b=10).group("b").having("b >= 10").order("b DESC").limit(2).offset(8).paginate(3, 10);
			
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
			
			// make sure the items were added
			assertEquals(["*"], loc.instance1.sql.select, "SELECT clause should accept '*'");
			assertEquals(loc.testVal, loc.instance2.sql.select, "SELECT clause should accept a list of columns");
			assertEquals(loc.testVal, loc.instance3.sql.select, "SELECT clause should accept a columns as multiple arguments");
		</cfscript>
	</cffunction>
	
	<cffunction name="testSelectAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// run chained selects to confirm appending with both syntaxes
			loc.instance = new().select("a,b").select("c","d").select("e,f");
			
			// make sure items were stacked/appended
			assertEquals(ListToArray("a,b,c,d,e,f"), loc.instance.sql.select, "SELECT should append additional selects");
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
			assertEquals("users", loc.instance.sql.from, "FROM clause should be set to passed value");
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
			assertEquals(1, ArrayLen(loc.instance.sql.wheres), "where() should only set one condition");
			assertEquals(0, ArrayLen(loc.instance.sql.whereParameters), "where() should not set any parameters");
			assertEquals("1 = 1", loc.instance.sql.wheres[1], "where() should append the correct condition");
		</cfscript>
	</cffunction>
	
	<cffunction name="testAppendWhere" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().where("1 = 1").where("2 = 2");
			assertEquals("2 = 2", loc.instance.sql.wheres[2], "where() should append the second condition");
		</cfscript>
	</cffunction>
	
	<cffunction name="testWhereWithParameters" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.whereClause = "id = ? OR name = '?' OR role IN ?";
			loc.whereParameters = [50, "admin", [1,2,3]];
			loc.instance = new().where(loc.whereClause, loc.whereParameters);
			assertEquals(loc.whereClause, loc.instance.sql.wheres[1], "where() should set the passed condition");
			assertEquals(loc.whereParameters, loc.instance.sql.whereParameters, "where() should set parameters in correct order");
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
			assertEquals(["a = ?", "b = ?", "c IN ?"], loc.instance.sql.wheres, "Named arguments should be in WHERE clause");
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
			assertEquals(loc.testVal, loc.instance1.sql.groups, "GROUP BY clause should accept a list of columns");
			assertEquals(loc.testVal, loc.instance2.sql.groups, "GROUP BY clause should accept a columns as multiple arguments");
		</cfscript>
	</cffunction>
	
	<cffunction name="testGroupAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// run chained groups to confirm appending with both syntaxes
			loc.instance = new().group("a,b").group("c","d").group("e,f");
			
			// make sure items were stacked/appended
			assertEquals(ListToArray("a,b,c,d,e,f"), loc.instance.sql.groups, "GROUP should append additional fields");
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
			assertEquals(1, ArrayLen(loc.instance.sql.havings), "having() should only set one condition");
			assertEquals(0, ArrayLen(loc.instance.sql.havingParameters), "having() should not set any parameters");
			assertEquals("a > 1", loc.instance.sql.havings[1], "having() should append the correct condition");
		</cfscript>
	</cffunction>
	
	<cffunction name="testAppendHaving" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = new().having("a > 1").having("b < 0");
			assertEquals("b < 0", loc.instance.sql.havings[2], "having() should append the second condition");
		</cfscript>
	</cffunction>
	
	<cffunction name="testHavingWithParameters" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.havingClause = "id = ? OR name = '?' OR role IN ?";
			loc.havingParameters = [50, "admin", [1,2,3]];
			loc.instance = new().having(loc.havingClause, loc.havingParameters);
			assertEquals(loc.havingClause, loc.instance.sql.havings[1], "having() should set the passed condition");
			assertEquals(loc.havingParameters, loc.instance.sql.havingParameters, "having() should set parameters in correct order");
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
			assertEquals(["a = ?", "b = ?", "c IN ?"], loc.instance.sql.havings, "Named arguments should be in HAVING clause");
			assertEquals([45, "BBB", [1,2,3]], loc.instance.sql.havingParameters, "Parameters should be set and in correct order");
		</cfscript>
	</cffunction>
	
	<cffunction name="testOrderSyntax" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.testVal = ListToArray("a ASC,b DESC,c");
			
			// run ORDER in various ways
			loc.instance1 = new().order("a ASC,b DESC,c");
			loc.instance2 = new().order("a ASC","b DESC","c");
			
			// make sure the items were added
			assertEquals(loc.testVal, loc.instance1.sql.orders, "ORDER BY clause should accept a list of columns");
			assertEquals(loc.testVal, loc.instance2.sql.orders, "ORDER BY clause should accept a columns as multiple arguments");
		</cfscript>
	</cffunction>
	
	<cffunction name="testOrderAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// run chained orders to confirm appending with both syntaxes
			loc.instance = new().order("a,b").order("c","d").order("e,f");
			
			// make sure items were stacked/appended
			assertEquals(ListToArray("a,b,c,d,e,f"), loc.instance.sql.orders, "ORDER should append additional fields");
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
	
	<cffunction name="testSqlGeneration" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = CreateObject("component", "cfrel.visitors.sql");
			
			// generate a simple relation
			loc.instance = new().select("a").from("b").where("a > 5").order("a ASC").paginate(2, 15);
			
			// make sure visitor is being called
			assertEquals(loc.visitor.visit(loc.instance), loc.instance.toSql(), "toSql() should be calling Sql visitor for SQL generation");
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
</cfcomponent>