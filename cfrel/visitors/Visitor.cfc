<cfcomponent displayName="Vistor" output="false">
	<cfinclude template="../functions.cfm" />
	
	<cffunction name="visit" returntype="any" access="public" hint="Visit a particular object">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// get metadata for object passed in
			loc.meta = getMetaData(arguments.obj);
			
			// is it a component?
			if (IsStruct(loc.meta) AND StructKeyExists(loc.meta, "type") AND loc.meta.type EQ "component") {
				
				// get classname of component passed in (and shorten name for cfrel.xxx.yyy to xxx.yyy)
				loc.type = REREplace(Replace(loc.meta.fullname, ".", "_", "ALL"), "^cfrel_", "");
				
			} else if (IsStruct(arguments.obj)) {
				
				// set up call to visit_struct
				loc.type = "struct";
				
			} else if (IsQuery(arguments.obj)) {
				
				// set up call to visit_query
				loc.type = "query";
				
			} else {
				
				// throw invalid type error
				throwException("Cannot visit object of unsupported type.");
			}
			
			// make sure method exists
			loc.method = "visit_#loc.type#";
			if (NOT(StructKeyExists(variables, loc.method) OR StructKeyExists(this, loc.method)))
				throwException("No visitor exists for type: #loc.type#");
			
			// call visit_xxx_yyy method
			return variables[loc.method](obj=arguments.obj);
		</cfscript>
	</cffunction>
</cfcomponent>