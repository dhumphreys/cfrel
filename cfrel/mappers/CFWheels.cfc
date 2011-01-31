<cfcomponent extends="Mapper" displayName="CFWheels" output="false">
	
	<cffunction name="buildMapping" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// TODO: a bug here will cause multiple joins on the same table to generate
			// errors with calculated properties out of ambiguous column names
			
			// get all models for relation
			variables.models = arguments.relation.buildModelArray();
			
			// loop over models used in relation
			loc.iEnd = ArrayLen(variables.models);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
				loc.model = injectInspector(variables.models[loc.i].model);
				loc.class = loc.model._inspect().wheels.class;
				
				// create a unique table alias
				loc.tableAlias = loc.class.modelName;
						
				// deal with alias conflicts
				for (loc.j = 2; StructKeyExists(variables.tables, loc.tableAlias); loc.j++)
					loc.tableAlias = loc.class.modelName & loc.j;
				
				// add table mapping to structure
				variables.models[loc.i].table = loc.class.tableName;
				variables.models[loc.i].alias = loc.tableAlias;
				variables.tables[loc.tableAlias] = loc.class.tableName;
				
				// loop over columns in model
				for (loc.key in loc.class.mapping) {
					loc.col = loc.class.mapping[loc.key];
					
					// build column data structure
					loc.colData = {};
					if (loc.col.type NEQ "sql") {
						loc.colData.value = loc.tableAlias & "." & loc.col.value;
						loc.colData.table = loc.tableAlias;
						loc.colData.cf_sql_type = loc.class.properties[loc.key].type;
					} else {
						loc.colData.value = loc.col.value;
					}
						
					// deal with column name conflicts
					if (StructKeyExists(variables.columns, loc.key)) {
						loc.key = loc.newName = loc.class.modelName & loc.key;
						
						// if it still conflicts, start appending numbers
						for (loc.j = 2; StructKeyExists(variables.columns, loc.key); loc.j++)
							loc.key = loc.newName & loc.j;
					}
					
					// add data structure to columns structure
					variables.columns[loc.key] = loc.colData;
				}
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="applyMapping" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			mapObject(relation.sql.select);
			mapObject(relation.sql.wheres);
			mapObject(relation.sql.groups);
			mapObject(relation.sql.havings);
			mapObject(relation.sql.orders);
		</cfscript>
	</cffunction>
	
	<cffunction name="mapObject" returntype="void" access="private">
		<cfargument name="obj" type="any" required="true" />
		<cfargument name="useAlias" type="boolean" default="true" />
		<cfscript>
			var loc = {};
			if (IsArray(arguments.obj)) {
				loc.iEnd = ArrayLen(arguments.obj);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
					mapObject(arguments.obj[loc.i], arguments.useAlias);
				break;
				
			} else {
				switch (typeOf(arguments.obj)) {
					
					// found a column node
					case "cfrel.nodes.column":
					
						// map the column to the correct database column
						if (NOT StructKeyExists(arguments.obj, "mapping") AND Len(arguments.obj.table) EQ 0) {
							if (StructKeyExists(variables.columns, arguments.obj.column)) {
								if (arguments.useAlias AND arguments.obj.alias EQ "")
									arguments.obj.alias = arguments.obj.column;
								arguments.obj.mapping = variables.columns[arguments.obj.column];
							}
						}
						break;
						
					// found a wildcard
					case "cfrel.nodes.wildcard":
					
						// map the wildcard to all available table columns
						arguments.obj.mapping = columnsFor(arguments.obj.subject);
						break;
						
					// found a function call
					case "cfrel.nodes.function":
					
						// turn off aliases under function calls
						arguments.useAlias = false;
						// dont' break here. we want execution to continue
						
					// else, see if we can go deeper in the tree
					default:
						if (IsStruct(arguments.obj)) {
							if (StructKeyExists(arguments.obj, "left"))
								mapObject(arguments.obj.left, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "right"))
								mapObject(arguments.obj.right, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "subject"))
								mapObject(arguments.obj.subject, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "args"))
								mapObject(arguments.obj.args, arguments.useAlias);
						}
				}
			}
		</cfscript>
	</cffunction>
</cfcomponent>