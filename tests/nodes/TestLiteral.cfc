<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "cfrel.nodes.literal";
		</cfscript>
	</cffunction>
	
	<cffunction name="testInit" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.node = new(init=false);
			assertFalse(StructKeyExists(loc.node, "content"), "Literal should not have content until init() is called");
			loc.literal = loc.node.init("SELECT 1");
			assertSame(loc.node, loc.literal, "init() should return the same object");
			assertEquals("SELECT 1", loc.literal.content, "Literal content should match that passed into constructor");
		</cfscript>
	</cffunction>
</cfcomponent>