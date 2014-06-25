<cfcomponent extends="Mapper" displayName="CFWheels" output="false">
	
	<cffunction name="mapTable" returntype="struct" access="public" hint="Append mapping information for a table node (unless it is a model)">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			if (typeOf(arguments.table) EQ "cfrel.nodes.model")
				return mapModel(arguments.table, arguments.map);
			else
				return super.mapTable(arguments.table, arguments.map);
		</cfscript>
	</cffunction>

	<cffunction name="mapModel" returntype="struct" access="public" hint="Append mapping information for a model and its properties">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = StructNew();

			// look up model data from cfwheels
			loc.model = arguments.table.model.$classData();

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = loc.model.tableName;
			loc.table.modelName = loc.model.modelName;
			loc.table.alias = uniqueScopeKey(key=loc.model.modelName, scope=arguments.map.tables);
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = loc.model.keys;

			// create a unique mapping for the table alias
			arguments.map.tables[loc.table.alias] = loc.table;

			// append alias to alias list for this table
			if (NOT structKeyExists(arguments.map.aliases, loc.model.modelName))
				arguments.map.aliases[loc.model.modelName] = ArrayNew(1);
			ArrayAppend(arguments.map.aliases[loc.model.modelName], loc.table.alias);

			// look up properties and associate them with an alias
			for (loc.key in loc.model.properties) {
				loc.col = StructNew();
				loc.col.property = loc.key;
				loc.col.column = loc.model.properties[loc.key].column;
				loc.col.table = loc.table.alias;
				loc.col.alias = uniqueScopeKey(key=loc.key, prefix=loc.table.alias, scope=arguments.map.columns);
				loc.col.mapping = "#loc.col.table#.#loc.col.column#";
				loc.col.cfsqltype = loc.model.properties[loc.key].type;
				loc.col.calculated = false;

				// create unique mappings for [alias], [table].[alias], [table].[property], and [table.column]
				arguments.map.columns[loc.col.alias] = loc.col;
				arguments.map.columns["#loc.col.table#.#loc.col.alias#"] = loc.col;
				if (NOT StructKeyExists(arguments.map.columns, "#loc.col.table#.#loc.col.property#"))
					arguments.map.columns["#loc.col.table#.#loc.col.property#"] = loc.col;
				if (NOT StructKeyExists(arguments.map.columns, "#loc.col.table#.#loc.col.column#"))
					arguments.map.columns["#loc.col.table#.#loc.col.column#"] = loc.col;

				// add to property list for table mapping
				loc.table.properties[loc.col.property] = loc.col;
			}

			// look up calculated properties and associate them with an alias
			for (loc.key in loc.model.calculatedProperties) {
				loc.col = StructNew();
				loc.col.property = loc.key;
				loc.col.alias = uniqueScopeKey(key=loc.key, prefix=loc.table.alias, scope=arguments.map.columns);
				loc.col.calculated = true;
		
				// map to custom sql from model (and solve ambiguous columns for single table calculated properties)
				loc.col.mapping = REReplace(loc.model.calculatedProperties[loc.key].sql, ":TABLE\b", loc.table.alias, "ALL");

				// create unique mappings for [alias], [table].[alias], [table].[property]
				arguments.map.columns[loc.col.alias] = loc.col;
				arguments.map.columns["#loc.table.alias#.#loc.col.alias#"] = loc.col;
				if (NOT StructKeyExists(arguments.map.columns, "#loc.table.alias#.#loc.col.property#"))
					arguments.map.columns["#loc.table.alias#.#loc.col.property#"] = loc.col;

				// add to calculated property list for table mapping
				loc.table.calculatedProperties[loc.col.property] = loc.col;
			}
		
			// TODO: figure out how to handle soft deletes with new mapping model
			// if the option is set, and the model has soft delete, consider it in the WHERE clause
			//if (NOT variables.includeSoftDeletes AND loc.model.$softDeletion())
			//	arguments.relation.where(loc.tableAlias & "." & loc.model.$softDeleteColumn() & " IS NULL");
		</cfscript>
		<cfreturn arguments.map />
	</cffunction>

	<cffunction name="mapInclude" returntype="struct" access="public" hint="Map include nodes using CFWheels association data">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="include" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = {};

			// keep track of a list of joins
			loc.joins = ArrayNew(1);

			// look up root model for relation
			// TODO: use last from in list and operate on from[last].joins
			loc.curr = StructNew();
			loc.curr.model = arguments.relation.sql.froms[1].model;
			loc.curr.associations = loc.curr.model.$classData().associations;
			if (Len(arguments.relation.sql.froms[1].alias))
				loc.curr.key = arguments.relation.sql.froms[1].alias;
			else
				loc.curr.key = arguments.map.aliases[loc.curr.model.$classData().modelName][1];
			loc.curr.mapping = arguments.map.tables[loc.curr.key];

			// push root model onto a stack
			loc.stack = ArrayNew(1);
			loc.stack[1] = loc.curr;
			//loc.includeStack = [variables.mappings.includes];
			
			// loop over the include string one character at a time
			loc.iEnd = Len(arguments.include.include);
			for (loc.pos = 1; loc.pos LTE loc.iEnd;) {
				
				// look at next character in include string
				switch(Mid(arguments.include.include, loc.pos, 1)) {
					
					// skip commas and spaces
					case ",":
					case " ":
						loc.pos++;
						break;
					
					// if we are stepping a level deeper, push the current model onto the stack
					case "(":
						ArrayPrepend(loc.stack, loc.curr);
						//ArrayPrepend(loc.includeStack, loc.includeStack[1][loc.key]);
						loc.pos++;
						break;
						
					// if we are stepping a level higher, pop the last model off of the stack
					case ")":
						ArrayDeleteAt(loc.stack, 1);
						loc.pos++;
						break;
						
					default:
				
						// grab the next association name
						loc.nextPos = REFind("\W", arguments.include.include, loc.pos, false);
						if (loc.nextPos EQ 0)
							loc.nextPos = Len(arguments.include.include) + 1;
						loc.key = Mid(arguments.include.include, loc.pos, loc.nextPos - loc.pos);
						loc.pos = loc.nextPos;
						
						// only join to the association if it was not previously included
						// TODO: figure out how to cancel out duplicate includes
						//if (NOT StructKeyExists(loc.includeStack[1], loc.key)) {
							//loc.includeStack[1][loc.key] = javaHash();

							// look up association and map table information
							if (NOT StructKeyExists(loc.stack[1].associations, loc.key))
								throwException("Association `#loc.key#` not found in model `#loc.stack[1].mapping.table#`.");
							loc.assoc = loc.stack[1].associations[loc.key];
							loc.table = sqlModel(model=loc.stack[1].model.model(loc.assoc.modelName));
							arguments.map = mapTable(loc.table, arguments.map);

							// look up root model for relation
							loc.curr = StructNew();
							loc.curr.model = loc.table.model;
							loc.curr.associations = loc.curr.model.$classData().associations;
							if (Len(loc.table.alias)) {
								loc.curr.key = loc.table.alias;
							} else {
								loc.aliases = arguments.map.aliases[loc.curr.model.$classData().modelName];
								loc.curr.key = loc.aliases[ArrayLen(loc.aliases)];
							}
							loc.curr.mapping = arguments.map.tables[loc.curr.key];
							
							// depending on association type, determine key lists for join
							if (loc.assoc.type EQ "belongsTo") {

								// set defaults for join key and foreign key
								if (NOT StructKeyExists(loc.assoc, "joinKey") OR loc.assoc.joinKey EQ "")
									loc.assoc.joinKey = loc.curr.mapping.primaryKey;
								if (loc.assoc.foreignKey EQ "")
									loc.assoc.foreignKey = REReplace(loc.curr.mapping.primaryKey, "(^|,)", "\1" & loc.curr.mapping.modelName, "ALL");

								// if association is 'belongsTo', use foreign key for left hand side
								loc.listA = loc.assoc.foreignKey;
								loc.listB = loc.assoc.joinKey;
								
							} else {

								// set defaults for join key and foreign key
								if (NOT StructKeyExists(loc.assoc, "joinKey") OR loc.assoc.joinKey EQ "")
									loc.assoc.joinKey = loc.stack[1].mapping.primaryKey;
								if (loc.assoc.foreignKey EQ "")
									loc.assoc.foreignKey = REReplace(loc.stack[1].mapping.primaryKey, "(^|,)", "\1" & loc.stack[1].mapping.modelName, "ALL");

								// if association is anything else, use foreign key for right hand side
								loc.listA = loc.assoc.joinKey;
								loc.listB = loc.assoc.foreignKey;
							}
							
							// create join condition between list A and list B
							loc.condition = ArrayNew(1);
							loc.jEnd = ListLen(loc.listA);
							for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++) {
								
								// handle opposite join directions
								loc.keyA = ListGetAt(loc.listA, loc.j);
								loc.keyB = ListGetAt(loc.listB, loc.j);
								
								// map the columns used in the left hand side of the join
								if (StructKeyExists(loc.stack[1].mapping.properties, loc.keyA))
									loc.columnA = loc.stack[1].mapping.alias & "." & loc.stack[1].mapping.properties[loc.keyA].column;
								else if (StructKeyExists(loc.stack[1].mapping.calculatedProperties, loc.keyA))
									loc.columnA = loc.stack[1].mapping.calculatedProperties[loc.keyA].sql;
								else
									throwException("Property `#loc.keyA#` not found in model `#loc.stack[1].mapping.modelName#`.");
								
								// map the columns used in the right hand side of the join
								if (StructKeyExists(loc.curr.mapping.properties, loc.keyB))
									loc.columnB = loc.curr.mapping.alias & "." & loc.curr.mapping.properties[loc.keyB].column;
								else if (StructKeyExists(loc.curr.mapping.calculatedProperties, loc.keyB))
									loc.columnB = loc.curr.mapping.calculatedProperties[loc.keyB].sql;
								else
									throwException("Property `#loc.keyB#` not found in model `#loc.curr.mapping.modelName#`.");
								
								// set up equality comparison between the two keys
								ArrayAppend(loc.condition, sqlBinaryOp(left=sqlColumn(loc.columnB), op="=", right=sqlColumn(loc.columnA)));
							}
					
							// if additional conditioning is specified, parse it out of include string
							// TODO: handle join parameters!
							loc.condPos = Find("[", arguments.include.include, loc.pos);
							if (loc.condPos EQ loc.pos) {
								loc.pos = Find("]", arguments.include.include, loc.condPos + 1) + 1;
								ArrayAppend(loc.condition, Mid(arguments.include.include, loc.condPos + 1, loc.pos - loc.condPos - 2));
							}

							// condense conditions into a single tree
							while (ArrayLen(loc.condition) GT 1) {
								loc.condition[2] = sqlBinaryOp(left=loc.condition[1], op="AND", right=loc.condition[2]);
								ArrayDeleteAt(loc.condition, 1);
							}
							
							// use the passed in join type, or the default for this association
							loc.joinType = (arguments.include.joinType EQ "") ? loc.assoc.joinType : arguments.include.joinType;
							
							// join to the table
							ArrayAppend(loc.joins, sqlJoin(loc.table, ArrayLen(loc.condition) ? loc.condition[1] : false, loc.joinType));
						//}
				}
			}

			// store generated joins by the 'includeKey' for later mapping
			arguments.map.includes[arguments.include.includeKey] = loc.joins;

		</cfscript>
		<cfreturn arguments.map />
	</cffunction>
	
	<cffunction name="buildStructCache" returntype="array" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfargument name="deep" type="boolean" default="false" />
		<cfargument name="flat" type="boolean" default="#NOT arguments.deep#" />
		<cfscript>
			if (IsObject(arguments.model) AND NOT arguments.flat)
				return arguments.model.$serializeQueryToStructs(arguments.query, includeString(), false, arguments.deep);
			return super.buildStructCache(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="buildObjectCache" returntype="array" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfargument name="deep" type="boolean" default="true" />
		<cfargument name="flat" type="boolean" default="false" />
		<cfscript>
			var loc = {};
			if (IsObject(arguments.model)) {
				loc.array = arguments.model.$serializeQueryToObjects(arguments.query, includeString(), false, arguments.deep AND NOT arguments.flat);
				if (arguments.flat) {
					loc.iEnd = ArrayLen(loc.array);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						loc.array[loc.i].setProperties(super.buildStruct(arguments.query, loc.i, arguments.model));
				}
				return loc.array;
			}
			return super.buildObjectCache(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="scopes" returntype="any" access="public">
		<cfargument name="model" type="any" required="true" />
		<cfreturn arguments.model.scopes() />
	</cffunction>
	
	<cffunction name="beforeFind" returntype="void" access="public" hint="Do before-find relation logic">
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// if recordset is paged, set up ordering like cfwheels
			// TODO: we are not making sure that all primary key fields are in the order clause here
			if (arguments.relation.isPaged() AND IsObject(arguments.relation.model) AND ArrayLen(arguments.relation.sql.orders) EQ 0) {
				
				// add the primary keys to the order list
				arguments.relation.order(arguments.relation.model.primaryKey());
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="afterFind" returntype="query" access="public" hint="Do after-find query processing">
		<cfargument name="model" type="any" required="true" />
		<cfargument name="query" type="query" required="true" />
		<cfscript>
			arguments.model.$callback("afterFind", true, arguments.query);
			return arguments.query;
		</cfscript>
	</cffunction>
	
</cfcomponent>