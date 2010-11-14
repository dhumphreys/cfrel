<cfcomponent extends="mxunit.Framework.TestCase">
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			variables.factory = CreateObject("component", "cfrel.relation");
		</cfscript>
	</cffunction>
	
	<cffunction name="testInit" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.obj = CreateObject("component", "cfrel.relation");
			loc.varCount1 = StructCount(loc.obj.variableDump());
			loc.instance = loc.obj.init();
			loc.varCount2 = StructCount(loc.instance.variableDump());
			
			// make sure init modifies instance, not creating a new one
			assertIsTypeOf(loc.instance, "cfrel.relation");
			assertSame(loc.obj, loc.instance, "init() should return same instance");
			assertTrue(loc.varCount2 GT loc.varCount1, "init() should define private variables");
		</cfscript>
	</cffunction>
	
	<cffunction name="testNew" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = factory.new();
			assertIsTypeOf(loc.instance, "cfrel.relation");
			assertNotSame(loc.instance, factory, "new() should create a new instance");
		</cfscript>
	</cffunction>
	
	<cffunction name="testClone" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = factory.new();
			loc.clone = loc.instance.clone();
			
			// make sure that call returns a different relation object
			assertIsTypeOf(loc.clone, "cfrel.relation");
			assertNotSame(loc.clone, loc.instance, "clone() should return copy of object, not same one")
		</cfscript>
	</cffunction>
	
	<cffunction name="testCallsAreChainable" returntype="void" access="public">
		<cfscript>
			var instance = factory.new();
			var key = "";
			var loc = {};
			
			// call each of the basic chainable methods
			loc.select = instance.select();
			loc.include = instance.include();
			loc.join = instance.join();
			loc.where = instance.where();
			loc.group = instance.group();
			loc.order = instance.order();
			loc.limit = instance.limit();
			loc.offset = instance.offset();
			
			// chain each call together for further testing
			loc.multiple = instance.select().include().join().where().order().limit().offset();
			
			// assert that each return is still the same object
			for (key in loc)
				assertSame(instance, loc[key]);
		</cfscript>
	</cffunction>
	
	<cffunction name="testVariableDump" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = factory.new();
			
			// make sure we get a dump of variables
			loc.dump = loc.instance.variableDump();
			assertTrue(IsStruct(loc.dump), "variableDump() should return reference to variable scope of instance");
		</cfscript>
	</cffunction>
</cfcomponent>