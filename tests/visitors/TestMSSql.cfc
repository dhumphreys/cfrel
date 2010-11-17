<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "cfrel.visitors.mssql";
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitRelation" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.sql = new();
			loc.factory = CreateObject("component", "cfrel.relation");
			
			// build a variety of queries
			loc.rel1 = loc.factory.new().select("a,b,c,d").distinct().from("example").limit(15);
			
			// set expected values
			loc.exp1 = "SELECT DISTINCT TOP 15 a, b, c, d FROM example";
			
			// test each value
			for (loc.i = 1; loc.i LTE 1; loc.i++)
				assertEquals(loc["exp#loc.i#"], loc.sql.visit(loc["rel#loc.i#"]));
		</cfscript>
	</cffunction>
</cfcomponent>