<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "cfrel.visitors.SqlServer";
		</cfscript>
	</cffunction>
	
	<cffunction name="testPagination" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = new();
			loc.factory = CreateObject("component", "cfrel.Relation");
			
			// build a variety of queries
			loc.rel1 = loc.factory.new().select("a,b,c,d").distinct().from("example").limit(15);
			loc.rel2 = loc.factory.new().select("a").from("example").order("a DESC").paginate(2, 5);
			
			// set expected values
			loc.exp1 = "SELECT DISTINCT TOP 15 a, b, c, d FROM example";
			loc.exp2 = "SELECT * FROM (SELECT a, ROW_NUMBER() OVER (ORDER BY a DESC) AS rowNum FROM example) paged_query WHERE rowNum BETWEEN 6 AND 10 ORDER BY rowNum ASC";
			
			// test each value
			for (loc.i = 1; loc.i LTE 2; loc.i++)
				assertEquals(loc["exp#loc.i#"], loc.visitor.visit(loc["rel#loc.i#"]));
		</cfscript>
	</cffunction>
	
	<cffunction name="testOnlyOffset" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.visitor = new();
			loc.rel = new("cfrel.Relation").select("c").offset(5);
			
			// should not allow OFFSET without LIMIT
			try {
				loc.visitor.visit(loc.rel);
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertTrue(loc.pass, "MS SQL Server should not allow only offset");
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptyOrder" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.visitor = new();
			loc.rel = new("cfrel.Relation").select("c").paginate(2, 10);
			
			// should not allow empty ORDER BY
			try {
				loc.visitor.visit(loc.rel);
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertTrue(loc.pass, "MS SQL Server should require ORDER BY when paging");
		</cfscript>
	</cffunction>
	
	<cffunction name="testDuplication" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = new();
			
			// perform TOP and ROW_NUMBER() style limits on data
			loc.rel1 = new("cfrel.Relation").select("a").order("a ASC").limit(5);
			loc.rel2 = new("cfrel.Relation").select("b").order("b DESC").limit(5).offset(10);
			
			// generate sql string
			loc.visitor.visit(loc.rel1);
			loc.visitor.visit(loc.rel2);
			
			// make sure original limit and offset are still left
			assertEquals(5, loc.rel1.sql.limit, "Original LIMIT should not be modified");
			assertEquals(5, loc.rel2.sql.limit, "Original LIMIT should not be modified");
			assertEquals(10, loc.rel2.sql.offset, "Original OFFSET should not be modified");
		</cfscript>
	</cffunction>
</cfcomponent>