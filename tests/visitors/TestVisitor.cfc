<cfcomponent extends="mxunit.Framework.TestCase" output="false">
	
	<cffunction name="testVisitCfrelObject" returntype="void" access="public">
		<cfscript>
			var loc = {};
			
			// mixin a visitor for cfrel.visitors.visitor
			loc.obj = CreateObject("component", "cfrel.visitors.visitor");
			loc.obj.visit_visitors_visitor = variables.visit_visitors_visitor;
			
			assertEquals(36, loc.obj.visit(loc.obj), "visit(obj) should call visit_visitors_visitor()")
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitStruct" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.set = {a=1,b=2,c=3};
			
			// mixin a visitor for structs
			loc.obj = CreateObject("component", "cfrel.visitors.visitor");
			loc.obj.visit_struct = visit_struct;
			
			assertEquals(StructCount(loc.set), loc.obj.visit(loc.set), "visit({}) should call visit_struct()");
		</cfscript>
	</cffunction>
	
	<cffunction name="testVisitQuery" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.query = QueryNew("id", "cf_sql_integer");
			
			// mixin a visitor for structs
			loc.obj = CreateObject("component", "cfrel.visitors.visitor");
			loc.obj.visit_query = visit_query;
			
			assertEquals(loc.query.recordCount, loc.obj.visit(loc.query), "visit(query) should call visit_query()");
		</cfscript>
	</cffunction>
	
	<cffunction name="testMissingVisitor" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.obj = CreateObject("component", "cfrel.visitors.visitor");
			try {
				loc.obj.visit(StructNew());
			} catch (custom_type e) {
				loc.pass = true;
			}
			assertFalse(StructKeyExists(loc.obj, "visit_struct"), "visit_struct() should not exist for this test to work");
			assertTrue(loc.pass, "Calling visit() on an invalid object should throw an error")
		</cfscript>
	</cffunction>
	
	<!------------------------
	--- Injectable Methods ---
	------------------------->
	
	<cffunction name="visit_visitors_visitor" returntype="numeric" access="private">
		<cfreturn 36 />
	</cffunction>
	
	<cffunction name="visit_struct" returntype="numeric" access="private">
		<cfreturn StructCount(arguments.obj) />
	</cffunction>
	
	<cffunction name="visit_query" returntype="numeric" access="private">
		<cfreturn arguments.obj.recordCount />
	</cffunction>
</cfcomponent>