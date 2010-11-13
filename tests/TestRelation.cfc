<cfcomponent extends="mxunit.Framework.TestCase">
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			variables.relation = CreateObject("component", "cfrel.relation").init()
		</cfscript>
	</cffunction>
	
	<cffunction name="testInit" returntype="void" access="public">
		<cfscript>
			assertIsTypeOf(variables.relation, "cfrel.relation");
		</cfscript>
	</cffunction>
	
	<cffunction name="testClone" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.relation = variables.relation.clone();
			
			// make sure that call returns a different relation object
			assertIsTypeOf(loc.relation, "cfrel.relation");
			assertNotSame(loc.relation, variables.relation, "clone() should return copy of object, not same one")
		</cfscript>
	</cffunction>
	
	<cffunction name="testCallsAreChainable" returntype="void" access="public">
		<cfscript>
			var key = "";
			var loc = {};
			
			// call each of the basic chainable methods
			loc.select = variables.relation.select();
			loc.include = variables.relation.include();
			loc.join = variables.relation.join();
			loc.where = variables.relation.where();
			loc.group = variables.relation.group();
			loc.order = variables.relation.order();
			loc.limit = variables.relation.limit();
			loc.offset = variables.relation.offset();
			
			// chain each call together for further testing
			loc.multiple = variables.relation.select().include().join().where().order().limit().offset();
			
			// assert that each return is still the same object
			for (key in loc)
				assertSame(variables.relation, loc[key]);
		</cfscript>
	</cffunction>
</cfcomponent>