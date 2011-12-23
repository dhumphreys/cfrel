<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "src.visitors.Sql";
		</cfscript>
	</cffunction>
	
	<!---
	TODO: Fix test that blows up
	
	<cffunction name="testVisitCfrelObject" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// mixin a visitor for cfrel.visitors.Visitor
			loc.obj = new();
			loc.obj._inspect().visit_visitors_visitor = variables.visit_visitors_visitor;
			
			assertEquals(36, loc.obj.visit(loc.obj), "visit(obj) should call visit_visitors_visitor()");
		</cfscript>
	</cffunction>
	--->
	
	<cffunction name="testVisitStruct" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.set = {a=1,b=2,c=3};
			
			// mixin a visitor for structs
			loc.obj = new();
			loc.obj._inspect().visit_struct = visit_struct;
			
			assertEquals(StructCount(loc.set), loc.obj.visit(loc.set), "visit({}) should call visit_struct()");
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitQuery" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.query = QueryNew("id", "cf_sql_integer");
			
			// mixin a visitor for structs
			loc.obj = new();
			loc.obj._inspect().visit_query = visit_query;
			
			assertEquals(loc.query.recordCount, loc.obj.visit(loc.query), "visit(query) should call visit_query()");
		</cfscript>
	</cffunction>
	
	<cffunction name="testMissingVisitor" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.obj = new();
			try {
				loc.obj.visit(StructNew());
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertFalse(StructKeyExists(loc.obj, "visit_struct"), "visit_struct() should not exist for this test to work");
			assertTrue(loc.pass, "Calling visit() on an invalid object should throw an error");
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitRelation" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.sql = new();
			loc.factory = CreateObject("component", "src.Relation");
			
			// build a variety of queries
			loc.rel1 = loc.factory.new().select("1 + 2", 3, 4).distinct();
			loc.rel2 = loc.factory.new().select("a, SUM(b)").from("example").group("a").having("SUM(b) > ?", [0]);
			loc.rel3 = loc.factory.new().from("example").where("c > 5 OR c < 2").where(a=5).order("c ASC");
			loc.rel4 = loc.factory.new().from("example").order("a DESC").paginate(7, 10);
			loc.rel5 = loc.factory.new().from(loc.rel4).where("b > ?", [10]);
			loc.rel6 = loc.factory.new().from(QueryNew(''));
			loc.rel7 = loc.factory.new().from(QueryNew('')).from(QueryNew(''));
			loc.rel8 = loc.factory.new().from(QueryNew('')).join(QueryNew(''), "a = b");
			
			// set expected values
			loc.exp1 = "SELECT DISTINCT 1 + 2, 3, 4";
			loc.exp2 = "SELECT a, SUM(b) FROM example GROUP BY a HAVING SUM(b) > ?";
			loc.exp3 = "SELECT * FROM example WHERE (c > 5 OR c < 2) AND a = ? ORDER BY c ASC";
			loc.exp4 = "SELECT * FROM example ORDER BY a DESC LIMIT 10 OFFSET 60";
			loc.exp5 = "SELECT * FROM (#loc.exp4#) subquery1 WHERE b > ?";
			loc.exp6 = "SELECT * FROM query1";
			loc.exp7 = "SELECT * FROM query1, query2";
			loc.exp8 = "SELECT * FROM query1, query2 WHERE a = b";
			
			// test each value
			for (loc.i = 1; loc.i LTE 8; loc.i++)
				assertEquals(loc["exp#loc.i#"], loc.sql.visit(loc["rel#loc.i#"]));
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitSimple" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = new();
			assertEquals(5, loc.visitor.visit(5));
			assertEquals("boo", loc.visitor.visit("boo"));
			assertEquals(true, loc.visitor.visit(true));
			assertEquals(Now(), loc.visitor.visit(Now()));
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitArray" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = new();
			loc.rel = new("src.Relation").select(1).from("a");
			loc.input = [5, "a", sqlLiteral("b"), loc.rel];
			loc.output = [5, "a", "b", "SELECT 1 FROM a"];
			assertEquals(loc.output, loc.visitor.visit(loc.input));
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitNodesLiteral" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.sql = new();
			assertEquals("SELECT 1", loc.sql.visit(sqlLiteral("SELECT 1")), "visit_literal() should just retain plain text contents");
		</cfscript>
	</cffunction>
	
	<!------------------------
	--- Injectable Methods ---
	------------------------->
	
	<cffunction name="visit_visitors_visitor" returntype="numeric" access="private">
		<cfreturn 36 />
	</cffunction>
	
	<cffunction name="visit_struct" returntype="numeric" access="private">
		<cfreturn StructCount(arguments.obj) />
	</cffunction>
	
	<cffunction name="visit_query" returntype="numeric" access="private">
		<cfreturn arguments.obj.recordCount />
	</cffunction>
</cfcomponent>