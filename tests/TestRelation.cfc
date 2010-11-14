<cfcomponent extends="mxunit.Framework.TestCase" output="false">
	
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
			loc.select = instance.select("a");
			loc.include = instance.include();
			loc.join = instance.join();
			loc.where = instance.where();
			loc.group = instance.group();
			loc.order = instance.order();
			loc.limit = instance.limit();
			loc.offset = instance.offset();
			
			// chain each call together for further testing
			loc.multiple = instance.select("b").include().join().where().order().limit().offset();
			
			// assert that each return is still the same object
			for (key in loc)
				assertSame(instance, loc[key]);
		</cfscript>
	</cffunction>
	
	<cffunction name="testSelectSyntax" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance1 = factory.new();
			loc.instance2 = factory.new();
			loc.instance3 = factory.new();
			loc.testVal = ListToArray("a,b,c");
			
			// run SELECT in various ways
			loc.instance1.select("*");
			loc.instance2.select("a,b,c");
			loc.instance3.select("a","b","c");
			
			// make sure the items were added
			loc.select1 = loc.instance1.variableDump().sql.select;
			loc.select2 = loc.instance2.variableDump().sql.select;
			loc.select3 = loc.instance3.variableDump().sql.select;
			assertEquals(["*"], loc.select1, "SELECT clause should accept '*'");
			assertEquals(loc.testVal, loc.select2, "SELECT clause should accept a list of columns");
			assertEquals(loc.testVal, loc.select3, "SELECT clause should accept a columns as multiple arguments");
		</cfscript>
	</cffunction>
	
	<cffunction name="testSelectAppend" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.instance = factory.new();
			
			// run chained selects to confirm appending with both syntaxes
			loc.instance.select("a,b").select("c","d").select("e,f");
			
			// make sure items were stacked/appended
			loc.select = loc.instance.variableDump().sql.select;
			assertEquals(ListToArray("a,b,c,d,e,f"), loc.select, "SELECT should append additional selects");
		</cfscript>
	</cffunction>
	
	<cffunction name="testEmptySelect" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.pass = false;
			loc.instance = factory.new();
			
			// confirm that exception is thrown
			try {
				loc.instance.select();
			} catch (Any e) {
				loc.pass = true;
			}
			
			assertTrue(loc.pass, "Empty parameters to SELECT should throw an error");
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