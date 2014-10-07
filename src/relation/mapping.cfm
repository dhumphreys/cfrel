<cffunction name="mapper" returntype="any" access="public" hint="Load a mapper for the desired element">
	<cfscript>
		var loc = {};
		
		// determine type of mapper to use
		if (this.model NEQ false)
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

		// read the map from internal cache if possible
		if (IsStruct(variables.map))
			return variables.map;

		// use the global cache if enabled and not a query of a query
		if (variables.cacheMap EQ true AND variables.qoq EQ false) {

			// generate unique key for this mapping
			var key = mapKey();
			if (key NEQ false) {

				// store the mapping in the global cache if it isn't there
				if (NOT inCache("map", key)) {
					variables.map = mapper().map(this);
					saveCache("map", key, variables.map);
				
				// read the map from cache and store it internally 
				} else {
					variables.map = loadCache("map", key);
				}

				return variables.map;
			}
		}
		
		// just generate the map, store it internally, and return
		variables.map = mapper().map(this);
		return variables.map;
	</cfscript>
</cffunction>

<cffunction name="mapKey" returntype="any" access="private" hint="Generate a unique key for the mapping structure based on joins">
	<cfscript>
		var loc = {};
		loc.key = "";

		// append FROM clause members to key
		for (loc.from in this.sql.froms) {
			switch (loc.from.$class) {
				case "cfrel.nodes.Table":
					loc.key = ListAppend(loc.key, "FROM:" & loc.from.table);
					break;
				case "cfrel.nodes.Model":
					loc.key = ListAppend(loc.key, "FROM_MODEL:" & loc.from.model & (loc.from.includeSoftDeletes ? ":INCLUDE_SOFT_DELETES" : ""));
					break;
				case "cfrel.nodes.Query":
					loc.key = ListAppend(loc.key, "FROM:query");
					break;
				case "cfrel.nodes.SubQuery":
					loc.key = ListAppend(loc.key, "FROM:subquery");
					break;

				// return false if an invalid member is encountered
				default:
					return false;
			}
		}

		// append JOIN clause subjects to key
		for (loc.join in this.sql.joins) {

			// for regular joins, just use their target table
			if (loc.join.$class EQ "cfrel.nodes.Join") {
				switch (loc.join.table.$class) {
					case "cfrel.nodes.Table":
						loc.key = ListAppend(loc.key, "JOIN:" & loc.join.table.table);
						break;
					case "cfrel.nodes.Model":
						loc.key = ListAppend(loc.key, "JOIN_MODEL:" & loc.join.table.model & (loc.join.includeSoftDeletes ? ":INCLUDE_SOFT_DELETES" : ""));
						break;
					case "cfrel.nodes.Query":
						loc.key = ListAppend(loc.key, "JOIN:query");
						break;
					case "cfrel.nodes.SubQuery":
						loc.key = ListAppend(loc.key, "JOIN:subquery");
						break;

					// return false if an invalid member is encountered
					default:
						return false;
				}

			// for includes, use their long include key
			} else if (loc.join.$class EQ "cfrel.nodes.Include") {
				loc.key = ListAppend(loc.key, "INCLUDE:" & loc.join.includeKey & (loc.join.includeSoftDeletes ? ":INCLUDE_SOFT_DELETES" : ""));

			// return false if an invalid member is encountered
			} else {
				return false;
			}
		}

		// hash the key and return
		return Hash(loc.key, Application.cfrel.HASH_ALGORITHM);
	</cfscript>
</cffunction>
