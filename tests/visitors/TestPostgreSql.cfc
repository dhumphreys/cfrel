<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "src.visitors.PostgreSql";
		</cfscript>
	</cffunction>
	
	<cffunction name="testColumnEscaping" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.visitor = new();
			loc.relation = new("src.Relation").select("a,b,c,SUM(e)").from("tableD").where(a=5).group("a,b,c").order("b ASC");
			
			// set expected value
			loc.expected = 'SELECT "a", "b", "c", SUM("e") FROM "tableD" WHERE "a" = ? GROUP BY "a", "b", "c" ORDER BY "b" ASC';
			
			// make sure columns are correctly escaped
			assertEquals(loc.expected, loc.visitor.visit(loc.relation));
		</cfscript>
	</cffunction>
</cfcomponent>