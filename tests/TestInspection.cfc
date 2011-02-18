<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
		</cfscript>
	</cffunction>
	
	<cffunction name="testInjectInspector" returntype="void" access="public">
		<cfscript>
			var obj = CreateObject("component", "SimpleObject");
			assertEquals(false, StructKeyExists(obj, "_inspect"));
			obj = injectInspector(obj);
			assertEquals(true, StructKeyExists(obj, "_inspect"));
		</cfscript>
	</cffunction>
	
</cfcomponent>