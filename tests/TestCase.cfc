<cfcomponent extends="mxunit.Framework.TestCase" output="false" hint="Base-class test for customer functionality/helpers/assertions">
	
	<cffunction name="setup" returntype="void" access="private" hint="Set up some defaults">
		<cfscript>
			variables.cfc = "component";
		</cfscript>
	</cffunction>
	
	<!----------------------------
	--- Private Helper Methods ---
	----------------------------->
	
	<cffunction name="new" returntype="any" access="private" hint="Initialize a CFC specified in variables.cfc or through arguments">
		<cfargument name="type" type="string" default="#variables.cfc#" />
		<cfargument name="init" type="boolean" default="true" />
		<cfscript>
			var obj = CreateObject("component", arguments.type);
			if (arguments.init AND StructKeyExists(obj, "init")) {
				StructDelete(arguments, "type");
				StructDelete(arguments, "init");
				obj.init(argumentCollection=arguments);
			}
			return injectInspector(obj);
		</cfscript>
	</cffunction>
	
	<cffunction name="injectInspector" returntype="any" access="private" hint="Make any object inspectable">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			if (NOT StructKeyExists(arguments.obj, "_inspect"))
				arguments.obj._inspect = variables._inspect;
			return arguments.obj;
		</cfscript>
	</cffunction>
	
	<!---------------------------
	--- Methods For Injection ---
	---------------------------->
	
	<cffunction name="_inspect" returntype="struct" access="private" hint="Method to return objects variables scope">
		<cfreturn variables />
	</cffunction>
</cfcomponent>