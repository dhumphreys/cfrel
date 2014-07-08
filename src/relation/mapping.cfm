<cffunction name="mapper" returntype="any" access="public" hint="Load a mapper for the desired element">
	<cfargument name="target" type="any" default="#this.model#" />
	<cfscript>
		var loc = {};
		
		// determine type of mapper to use
		if (typeOf(arguments.target) EQ "model")
			loc.type = "CFWheels";
		else
			loc.type = "Mapper";
		
		// lazy load a cache for mapper types
		if (NOT StructKeyExists(request, "mappers"))
			request.mappers = {};
		
		// lazy load the mapper needed for the passed object
		if (NOT StructKeyExists(request.mappers, loc.type))
			request.mappers[loc.type] = CreateObject("component", addCfcPrefix("cfrel.mappers.#loc.type#")).init();
		
		// return mapper from the request scope
		return request.mappers[loc.type];
	</cfscript>
</cffunction>

<cffunction name="visitor" returntype="any" access="public" hint="Load a visitor for the desired DBMS">
	<cfargument name="type" type="string" default="#variables.visitorClass#" />
	<cfscript>
		// lazy load a cache for visitor types
		if (NOT StructKeyExists(request, "visitors"))
			request.visitors = {};
		
		// lazy load the visitor needed for the passed object
		if (NOT StructKeyExists(request.visitors, arguments.type))
			request.visitors[arguments.type] = CreateObject("component", addCfcPrefix("cfrel.visitors.#arguments.type#")).init();
		
		// return visitor from the request scope
		return request.visitors[arguments.type];
	</cfscript>
</cffunction>

<cffunction name="getMap" returntype="struct" access="public" hint="Build a struct to map table and column references for this relation to the datasource">
	<cfscript>
		if (NOT IsStruct(variables.map))
			variables.map = mapper().map(this);
		return variables.map;
	</cfscript>
</cffunction>
