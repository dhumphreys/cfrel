<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "src.visitors.MySql";
		</cfscript>
	</cffunction>
</cfcomponent>