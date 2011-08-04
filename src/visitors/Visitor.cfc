<cfcomponent displayName="Vistor" output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="visit" returntype="any" access="public" hint="Visit a particular object">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// find type of object
			loc.type = typeOf(arguments.obj);
			
			// get classname of component passed in (and shorten name for cfrel.xxx.yyy to xxx.yyy)
			if (REFind("^(\w+)(\.\w+)+$", loc.type))
				loc.type = REREplace(Replace(loc.type, ".", "_", "ALL"), "^cfrel_", "");
			
			// construct method name for type. throw exception if it doesnt exist
			loc.method = "visit_#loc.type#";
			if (NOT StructKeyExists(variables, loc.method))
				throwException("No visitor exists for type: #loc.type#");
			
			// call visit_xxx_yyy method
			var method = variables[loc.method];
			return method(argumentCollection=arguments);
		</cfscript>
	</cffunction>
</cfcomponent>