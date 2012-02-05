<cffunction name="mapper" returntype="any" access="public" hint="Load a mapper for the desired element">
	<cfargument name="target" type="any" default="#this.model#" />
	<cfscript>
		var loc = {};
		
		// determine type of mapper to use
		switch (typeOf(arguments.target)) {
			case "model":
				loc.type = "CFWheels";
				break;
			case "query":
				// TODO: build query-of-query mapper
			case "cfrel.nodes.subquery":
				// TODO: build subquery mapper
			default:
				loc.type = "Mapper";
		}
		
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
	
<cffunction name="buildMappings" returntype="void" access="public" hint="Force pending mappings to be built into search trees">
	<cfscript>
		// loop until pending queue is empty
		while (ArrayLen(variables.mappings.queue)) {
			
			// perform mappings from the queue and then pop them
			buildTableMapping(variables.mappings.queue[1]);
			ArrayDeleteAt(variables.mappings.queue, 1);
		}
	</cfscript>
</cffunction>

<cffunction name="queueMapping" returntype="void" access="public" hint="Queue up mappings to be performed later">
	<cfargument name="subject" type="any" required="true" />
	<cfset ArrayAppend(variables.mappings.queue, arguments.subject) />
</cffunction>

<cffunction name="buildTableMapping" returntype="boolean" access="public" hint="Map the alias and columns for a from source">
	<cfargument name="table" type="any" required="true" />
	<cfscript>
		var loc = {};
		
		// determine subject to use
		if (typeOf(arguments.table) EQ "cfrel.nodes.subquery")
			loc.subject = arguments.table;
		else if (StructKeyExists(arguments.table, "model") AND IsObject(arguments.table.model))
			loc.subject = arguments.table.model;
		else if (StructKeyExists(arguments.table, "include"))
			return buildIncludeMapping(from=this.sql.froms[ArrayLen(this.sql.froms)], argumentCollection=arguments.table);
		else
			loc.subject = arguments.table;
		
		// determine mapper to use
		loc.mapper = mapper(loc.subject);
		
		// TODO: append model to mapper. why?
		// ArrayAppend(variables.models, arguments.table);
		
		// assign table alias
		loc.tableAlias = uniqueScopeKey(key=loc.mapper.aliasName(loc.subject), scope=variables.mappings.tableAlias);
		arguments.table.table = loc.mapper.tableName(loc.subject);
		arguments.table.alias = loc.tableAlias;
		
		// add table data to proper mapping structures
		variables.mappings.tableAlias[loc.tableAlias] = arguments.table.table;
		loc.tableCols = variables.mappings.tableColumns[loc.tableAlias] = {};
		
		// loop over database properties in model
		loc.properties = loc.mapper.properties(loc.subject);
		for (loc.key in loc.properties) {
			loc.col = loc.properties[loc.key];
			
			// store original column for last mapping key
			loc.origCol = loc.col.column;
			
			// determine a unique alias for this property in the query
			loc.col.alias = uniqueScopeKey(key=loc.col.property, prefix=loc.tableAlias, scope=variables.mappings.columns);
			
			// store the table alias with the column information for later rendering
			loc.col.column = loc.tableAlias & "." & loc.col.column;
			loc.col.table = loc.tableAlias;
			
			// make column mappable by: [property_alias]
			variables.mappings.columns[loc.col.alias] = loc.col;
			
			// make column mappable by: [table_alias].[property_alias]
			loc.tableCols[loc.col.alias] = loc.col;
			
			// make column mappable by: [table_alias].[property]
			if (NOT StructKeyExists(loc.tableCols, loc.col.property))
				loc.tableCols[loc.col.property] = loc.col;
				
			// make column mappable by: [table_alias].[column]
			if (NOT StructKeyExists(loc.tableCols, loc.origCol))
				loc.tableCols[loc.origCol] = loc.col;
		}
		
		// loop over calculated properties in model
		loc.properties = loc.mapper.calculatedProperties(loc.subject);
		for (loc.key in loc.properties) {
			loc.col = loc.properties[loc.key];
			
			// determine a unique alias for this property in the query
			loc.col.alias = uniqueScopeKey(key=loc.col.property, prefix=loc.tableAlias, scope=variables.mappings.columns);
			
			// TODO: a bug here will cause multiple joins on the same table to generate
			// errors with calculated properties out of ambiguous column names
		
			// handle ambiguous columns for single table calculated properties
			loc.col.sql = REReplace(loc.col.sql, ":TABLE\b", loc.tableAlias, "ALL");
			
			// make column mappable by: [property_alias]
			variables.mappings.columns[loc.col.alias] = loc.col;
			
			// make column mappable by: [table_alias].[property_alias]
			loc.tableCols[loc.col.alias] = loc.col;
			
			// make column mappable by: [table_alias].[column]
			if (NOT StructKeyExists(loc.tableCols, loc.col.property))
				loc.tableCols[loc.col.property] = loc.col;
		}
		
		// TODO: figure out how to handle soft deletes with new mapping model
		// if the option is set, and the model has soft delete, consider it in the WHERE clause
		//if (NOT variables.includeSoftDeletes AND loc.model.$softDeletion())
		//	arguments.relation.where(loc.tableAlias & "." & loc.model.$softDeleteColumn() & " IS NULL");
			
		return true;
	</cfscript>
</cffunction>

<cffunction name="buildIncludeMapping" returntype="boolean" access="public" hint="Map the alias and columns for a join">
	<cfargument name="include" type="string" required="true" />
	<cfargument name="params" type="array" required="true" />
	<cfargument name="joinType" type="string" required="true" />
	<cfargument name="from" type="any" required="true" />
	<cfscript>
		var loc = {};
		
		// get mapper from latest FROM selection
		loc.mapper = mapper(arguments.from.model);
			
		// set up control stacks
		loc.modelStack = [arguments.from.model];
		loc.aliasStack = [arguments.from.alias];
		loc.includeStack = [variables.mappings.includes];
		
		// loop over joined items
		loc.iEnd = Len(arguments.include);
		for (loc.pos = 1; loc.pos LTE loc.iEnd;) {
			
			// look at next character in include string
			switch(Mid(arguments.include, loc.pos, 1)) {
				
				// skip commas and spaces
				case ",":
				case " ":
					loc.pos++;
					break;
				
				// if we are stepping a level deeper
				case "(":
				
					// push the last model onto the stack
					ArrayPrepend(loc.modelStack, loc.assoc.model);
					ArrayPrepend(loc.aliasStack, loc.includeStack[1][loc.key]["_alias"]);
					ArrayPrepend(loc.includeStack, loc.includeStack[1][loc.key]);
					loc.pos++;
					break;
					
				// if we are stepping a level higher
				case ")":
				
					// pop the last model off of the stack
					ArrayDeleteAt(loc.modelStack, 1);
					ArrayDeleteAt(loc.aliasStack, 1);
					ArrayDeleteAt(loc.includeStack, 1);
					loc.pos++;
					break;
					
				default:
			
					// grab the next association name
					loc.nextPos = REFind("\W", arguments.include, loc.pos, false);
					if (loc.nextPos EQ 0)
						loc.nextPos = Len(arguments.include) + 1;
					loc.key = Mid(arguments.include, loc.pos, loc.nextPos - loc.pos);
					loc.pos = loc.nextPos;
					
					// get association data from mapper
					loc.assoc = loc.mapper.association(loc.modelStack[1], loc.key);
					
					// only join to the association if it was not previously included
					if (NOT StructKeyExists(loc.includeStack[1], loc.key)) {
						loc.includeStack[1][loc.key] = javaHash();
				
						// build mapping for current model
						loc.associationTable = sqlTable(model=loc.assoc.model);
						buildTableMapping(loc.associationTable);
						
						// determine table aliases to use
						loc.modelAlias = loc.aliasStack[1];
						loc.includeStack[1][loc.key]["_alias"] = loc.associationTable.alias;
						
						// determine join keys to use
						if (loc.assoc.type EQ "belongsTo") {
							
							// find primary keys of other join
							loc.keys = loc.mapper.primaryKey(loc.assoc.model);
							
							// guess join key if not set
							if (NOT StructKeyExists(loc.assoc, "joinKey") OR loc.assoc.joinKey EQ "")
								loc.assoc.joinKey = loc.keys;
							 
							// guess foreign key if not set
							if (loc.assoc.foreignKey EQ "")
								loc.assoc.foreignKey = REReplace(loc.keys, "(^|,)", "\1" & loc.assoc.modelName, "ALL");
								
							// set up two lists of join keys
							loc.listA = loc.assoc.foreignKey;
							loc.listB = loc.assoc.joinKey;
							
						} else {
							
							// find primary keys of other join
							loc.keys = loc.mapper.primaryKey(loc.assoc.model);
							
							// guess join key if not set
							if (NOT StructKeyExists(loc.assoc, "joinKey") OR loc.assoc.joinKey EQ "")
								loc.assoc.joinKey = loc.keys;
								
							// guess foreign key if not set
							if (loc.assoc.foreignKey EQ "")
								loc.assoc.foreignKey = REReplace(loc.keys, "(^|,)", "\1" & loc.mapper.aliasName(loc.modelStack[1]), "ALL");
								
							// set up two lists of join keys
							loc.listA = loc.assoc.joinKey;
							loc.listB = loc.assoc.foreignKey;
						}
						
						// find columns and calculated properties for joined models
						// TODO: use the columns mapped from the buildTableMapping() call above
						loc.propertiesA = loc.mapper.properties(loc.modelStack[1]);
						loc.calculatedA = loc.mapper.calculatedProperties(loc.modelStack[1]);
						loc.propertiesB = loc.mapper.properties(loc.assoc.model);
						loc.calculatedB = loc.mapper.calculatedProperties(loc.assoc.model);
						
						// create join condition between list A and list B
						loc.condition = "";
						loc.jEnd = ListLen(loc.assoc.foreignKey);
						for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++) {
							
							// handle opposite join directions
							loc.keyA = ListGetAt(loc.listA, loc.j);
							loc.keyB = ListGetAt(loc.listB, loc.j);
							
							// determine column or mapping for column A
							if (StructKeyExists(loc.propertiesA, loc.keyA))
								loc.columnA = loc.modelAlias & "." & loc.propertiesA[loc.keyA].column;
							else if (StructKeyExists(loc.calculatedA, loc.keyA))
								loc.columnA = loc.modelAlias & "." & loc.calculatedA[loc.keyA].sql;
							else
								throwError("Column `#loc.keyA#` not found in `#loc.modelAlias#`.");
							
							// determine column or mapping for column B
							if (StructKeyExists(loc.propertiesB, loc.keyB))
								loc.columnB = loc.includeStack[1][loc.key]['_alias'] & "." & loc.propertiesB[loc.keyB].column;
							else if (StructKeyExists(loc.calculatedA, loc.keyA))
								loc.columnB = loc.includeStack[1][loc.key]['_alias'] & "." & loc.calculatedB[loc.keyB].sql;
							else
								throwError("Column `#loc.keyB#` not found in `#loc.modelAlias#`.");
							
							// set up equality comparison between the two keys
							loc.condition =  ListAppend(loc.condition, "#loc.columnB# = #loc.columnA#", Chr(7));
						}
						
						// format condition for ON clause
						loc.condition = Replace(loc.condition, Chr(7), " AND ", "ALL");
				
						// if additional conditioning is specified, parse it out
						loc.condPos = Find("[", arguments.include, loc.pos);
						if (loc.condPos EQ loc.pos) {
							loc.pos = Find("]", arguments.include, loc.condPos + 1) + 1;
							loc.condition &= " AND " & Mid(arguments.include, loc.condPos + 1, loc.pos - loc.condPos - 2);
						}
						
						// use the passed in join type, or the default for this association
						loc.joinType = (arguments.joinType EQ "") ? loc.assoc.joinType : arguments.joinType;
						
						// join to the table, making sure not to map the table twice
						this.join(loc.associationTable, loc.condition, [], loc.joinType, true);
					}
			}
		}
		
		return true;
	</cfscript>
</cffunction>

<!---
<cffunction name="mapTable" returntype="struct" access="public" hint="Use mapping tree to set table node information">
	<cfscript>
		// also try to map hard table names into aliases
		// FROM OLD CODE
		if (Len(arguments.obj.table)) {
			loc.iEnd = ArrayLen(variables.models);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				if (variables.models[loc.i].table EQ arguments.obj.table) {
					arguments.obj.table = variables.models[loc.i].alias;
					break;
				}
			}
		}
	</cfscript>
</cffunction>
--->

<cffunction name="mapColumn" returntype="struct" access="public" hint="Use mapping tree to set column node information">
	<cfargument name="column" type="struct" required="true" hint="Column node to map" />
	<cfscript>
		var loc = {};
		
		// search for the column mapping in requested scope
		loc.mapping = $findColumnMapping(arguments.column.column);
		
		// if a mapping is found, apply changes to column
		if (IsStruct(loc.mapping)) {
			arguments.column = Duplicate(arguments.column);
			
			// if no alias is set, use the pre-mapped column name
			if (NOT Len(arguments.column.alias))
				arguments.column.alias = ListLast(arguments.column.column, ".");
			
			// if a sql mapping is found, use it instead of column name
			if (StructKeyExists(loc.mapping, "sql")) {
				arguments.column.sql = loc.mapping.sql;
				arguments.column.column = "";
				
			// if a mapped column name is found, use it
			} else if (StructKeyExists(loc.mapping, "column")) {
				arguments.column.column = loc.mapping.column;
			}
		}
		
		return arguments.column;
	</cfscript>
</cffunction>

<cffunction name="mapWildcard" returntype="struct" access="public" hint="Use mapping tree to set wildcard node columns">
	<cfargument name="wildcard" type="struct" required="true" />
	<cfscript>
		var loc = {};
		
		// duplicate node and set up wildcard mapping
		arguments.wildcard = Duplicate(arguments.wildcard);
		arguments.wildcard.mapping = ArrayNew(1);
		
		// loop over all columns
		for (loc.key in variables.mappings.columns) {
			loc.col = variables.mappings.columns[loc.key];
			
			// return columns all matching wildcard (but not calculated columns)
			if (StructKeyExists(loc.col, "table") AND (Len(arguments.wildcard.subject) EQ 0 OR loc.col.table EQ arguments.wildcard.subject))
				ArrayAppend(arguments.wildcard.mapping, sqlColumn(column=loc.col.column, alias=loc.key));
		}
		
		return arguments.wildcard;
	</cfscript>
</cffunction>

<cffunction name="mapParameter" returntype="struct" access="public" hint="Use mapping tree to set parameter node information">
	<cfargument name="param" type="struct" required="true" />
	<cfscript>
		var loc = {};
		
		// if column is set, search mapping tree for data type
		if (StructKeyExists(arguments.param, "column")) {
			
			// remove column from input
			loc.column = arguments.param.column;
			StructDelete(arguments.param, "column");
			
			// look up column mapping and set cfsqltype
			loc.mapping = $findColumnMapping(loc.column);
			if (IsStruct(loc.mapping) AND StructKeyExists(loc.mapping, "cfsqltype"))
				arguments.param.cfsqltype = loc.mapping.cfsqltype;
				
			// if no mapping is found, give it our best guess
			// TODO: never do IsNumeric() for this check
			else if (IsNumeric(arguments.param.value))
				arguments.param.cfsqltype = "cf_sql_numeric";
			else
				arguments.param.cfsqltype = "cf_sql_char";
		}
		
		return arguments.param;
	</cfscript>
</cffunction>

<cffunction name="$findColumnMapping" returntype="any" access="private" hint="Search for a column mapping by column name">
	<cfargument name="column" type="string" required="true" />
	<cfscript>
		var loc = {};
		
		// default the column search to all mappings
		loc.scope = variables.mappings.columns;
		
		// if a table is specified, search only the scope of the table
		loc.length = ListLen(arguments.column, ".");
		if (loc.length GT 1) {
			loc.table = ListDeleteAt(arguments.column, loc.length, ".");
			if (StructKeyExists(variables.mappings.tableColumns, loc.table))
				loc.scope = variables.mappings.tableColumns[loc.table];
			else
				loc.scope = [];
			arguments.column = ListLast(arguments.column, ".");
		}
		
		// look for column in scope, and return if found
		if (StructKeyExists(loc.scope, arguments.column))
			return loc.scope[arguments.column];
		
		// otherwise, return false
		return false;
	</cfscript>
</cffunction>
