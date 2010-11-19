<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
		</cfscript>
	</cffunction>
	
	<cffunction name="testLiteral" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.node = literal("ROW_NUMBER()");
			assertIsTypeOf(loc.node, "cfrel.nodes.Literal");
			assertEquals("ROW_NUMBER()", loc.node.content, "Literal node should be constructed with correct value");
		</cfscript>
	</cffunction>
	
	<cffunction name="testThrowException" returntype="void" access="public">
		<cfscript>
			var pass = false;
			try {
				throwException("Test Throw");
			} catch (custom_type e) {
				pass = true;
			}
			assertTrue(pass, "throwException() should have thrown an exception.");
		</cfscript>
	</cffunction>
	
	<cffunction name="testTypeOf" returntype="void" access="public">
		<cfscript>
			assertEquals("array", typeOf([]));
			assertEquals("query", typeOf(QueryNew('')));
			assertEquals("struct", typeOf({}));
			assertEquals("binary", typeOf(ToBinary(ToBase64("1234"))));
			assertEquals("function", typeOf(literal));
			assertEquals("cfrel.nodes.Literal", typeOf(literal("SELECT a FROM b")));
		</cfscript>
	</cffunction>
</cfcomponent>