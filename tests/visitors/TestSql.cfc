<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "cfrel.visitors.sql";
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitRelation" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.sql = new();
			loc.factory = CreateObject("component", "cfrel.relation");
			
			// build a variety of queries
			loc.rel1 = loc.factory.new().select("1 + 2", 3, 4);
			loc.rel2 = loc.factory.new().select("a, SUM(b) AS c").from("example").group("a").having("SUM(b) > ?", [0]);
			loc.rel3 = loc.factory.new().from("example").where("c > 5 OR c < 2").where("a"=5).order("c ASC");
			loc.rel4 = loc.factory.new().from("example").order("a DESC").paginate(7, 10);
			loc.rel5 = loc.factory.new().from(loc.rel4).where("b > ?", [10]);
			
			// set expected values
			loc.exp1 = "SELECT 1 + 2, 3, 4";
			loc.exp2 = "SELECT a, SUM(b) AS c FROM example GROUP BY a HAVING SUM(b) > ?";
			loc.exp3 = "SELECT * FROM example WHERE (c > 5 OR c < 2) AND a = ? ORDER BY c ASC";
			loc.exp4 = "SELECT * FROM example ORDER BY a DESC LIMIT 10 OFFSET 60";
			loc.exp5 = "SELECT * FROM (#loc.exp4#) WHERE b > ?"
			
			// test each value
			for (loc.i = 1; loc.i LTE 5; loc.i++)
				assertEquals(loc["exp#loc.i#"], loc.sql.visit(loc["rel#loc.i#"]));
		</cfscript>
	</cffunction>
</cfcomponent>