<cfcomponent extends="mxunit.framework.TestCase" output="false" hint="Base-class test for customer functionality/helpers/assertions">
	<cfinclude template="/cfrel/functions.cfm" />
	
	<cffunction name="setup" returntype="void" access="private" hint="Set up some defaults">
		<cfscript>
			variables.cfc = "railo-context.component";
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
</cfcomponent>