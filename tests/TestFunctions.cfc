<cfinclude template="/cfrel/functions.cfm" />
<cfcomponent extends="mxunit.Framework.TestCase" output="false">
	<cffunction name="testThrowException" returntype="void" access="public">
		<cfscript>
			var pass = false
			try {
				throwException("Test Throw", "Object");
			} catch (Any e) {
				pass = true;
			}
			assertTrue(pass, "throwException() should have thrown an exception.");
		</cfscript>
	</cffunction>
</cfcomponent>