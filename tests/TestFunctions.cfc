<cfcomponent extends="tests.TestCase" output="false">
	<cfinclude template="/cfrel/functions.cfm" />
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
		</cfscript>
	</cffunction>
	
	<cffunction name="testThrowException" returntype="void" access="public">
		<cfscript>
			var pass = false
			try {
				throwException("Test Throw", "Object");
			} catch (Object e) {
				pass = true;
			}
			assertTrue(pass, "throwException() should have thrown an exception.");
		</cfscript>
	</cffunction>
	
	<cffunction name="testLiteral" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.node = literal("ROW_NUMBER()");
			assertIsTypeOf(loc.node, "cfrel.nodes.literal");
			assertEquals("ROW_NUMBER()", loc.node.content, "Literal node should be constructed with correct value");
		</cfscript>
	</cffunction>
</cfcomponent>