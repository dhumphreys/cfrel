<cfcomponent extends="Mapper" displayName="CFWheels" output="false">
	
	<cffunction name="buildMapping" returntype="void" access="public">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// TODO: a bug here will cause multiple joins on the same table to generate
			// errors with calculated properties out of ambiguous column names
			
			// append model to mapper
			ArrayAppend(variables.models, arguments.table);
			
			// pull model and class name from table parameter
			loc.model = injectInspector(arguments.table.model);
			loc.class = loc.model._inspect().wheels.class;
				
			// create a unique table alias
			loc.tableAlias = uniqueScopeKey(key=loc.class.modelName, scope=variables.tables);
			
			// add table mapping to structure
			arguments.table.table = loc.class.tableName;
			arguments.table.alias = loc.tableAlias;
			variables.tables[loc.tableAlias] = loc.class.tableName;
			
			// loop over columns in model
			for (loc.key in loc.class.properties) {
				loc.col = loc.class.properties[loc.key];
				
				// build column data structure
				loc.colData = {};
				loc.colData.value = loc.tableAlias & "." & loc.col.column;
				loc.colData.table = loc.tableAlias;
				loc.colData.cf_sql_type = loc.col.type;
					
				// deal with column name conflicts
				loc.key = uniqueScopeKey(key=loc.key, prefix=loc.class.modelName, scope=variables.columns);
				
				// add data structure to columns structure
				variables.columns[loc.key] = loc.colData;
			}
			
			// loop over calculated properties in model
			for (loc.key in loc.class.calculatedProperties) {
				loc.col = loc.class.calculatedProperties[loc.key];
				
				// build column data structure
				loc.colData = {};
				loc.colData.value = loc.col.sql;
					
				// deal with column name conflicts
				loc.key = uniqueScopeKey(key=loc.key, prefix=loc.class.modelName, scope=variables.columns);
				
				// add data structure to columns structure
				variables.columns[loc.key] = loc.colData;
			}
			
			// if the option is set, and the model has soft delete, consider it in the WHERE clause
			if (NOT variables.includeSoftDeletes AND loc.model.$softDeletion())
				arguments.relation.where(loc.tableAlias & "." & loc.model.$softDeleteColumn() & " IS NULL");
		</cfscript>
	</cffunction>
	
	<cffunction name="columnDataType" returntype="any" access="public">
		<cfargument name="column" type="string" required="true" />
		<cfscript>
			// todo: make tableName.columnName work here
			arguments.column = ListLast(arguments.column, ".");
			
			if (StructKeyExists(variables.columns, arguments.column) AND StructKeyExists(variables.columns[arguments.column], "cf_sql_type"))
				return variables.columns[arguments.column].cf_sql_type;
			return "cf_sql_char";
		</cfscript>
	</cffunction>
	
	<cffunction name="mapIncludes" returntype="void" access="public">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="include" type="string" required="true" />
		<cfscript>
			var loc = {};
			
			// get last FROM item
			loc.from = relation.sql.froms[ArrayLen(relation.sql.froms)];
			
			// throw error if FROM is not a model
			if (typeOf(loc.from.model) NEQ "model")
				throwException("Includes can only be used with models");
			
			// set up join level tracking and current model class
			loc.levels = [loc.from.model];
			loc.private = injectInspector(loc.from.model)._inspect();
			loc.class = loc.private.wheels.class;
			
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
						ArrayAppend(loc.levels, loc.model);
						loc.class = loc.model._inspect().wheels.class;
						loc.pos++;
						break;
						
					// if we are stepping a level higher
					case ")":
					
						// pop the last model off of the stack
						ArrayDeleteAt(loc.levels, ArrayLen(loc.levels));
						loc.class = loc.levels[ArrayLen(loc.levels)]._inspect().wheels.class;
						loc.pos++;
						break;
						
					default:
				
						// grab the next association name
						loc.nextPos = REFind("\W", arguments.include, loc.pos, false);
						if (loc.nextPos EQ 0)
							loc.nextPos = Len(arguments.include) + 1;
						loc.key = Mid(arguments.include, loc.pos, loc.nextPos - loc.pos);
						loc.pos = loc.nextPos;
						
						// look up association and model
						loc.assoc = loc.class.associations[loc.key];
						loc.model = injectInspector(loc.from.model.model(loc.assoc.modelName));
						loc.otherClass = loc.model._inspect().wheels.class;
					
						// build mapping for current model
						loc.table = sqlTable(model=loc.model);
						buildMapping(loc.table, arguments.relation);
						
						// determine table aliases to use
						loc.tableA = getLastTableAlias(loc.class.tableName, loc.class.modelName);
						loc.tableB = getLastTableAlias(loc.otherClass.tableName, loc.otherClass.modelName);
						
						// determine join keys to use
						loc.listA = loc.assoc.type NEQ "belongsTo" ? loc.class.keys : loc.assoc.foreignKey;
						loc.listB = loc.assoc.type NEQ "belongsTo" ? loc.assoc.foreignKey : loc.otherClass.keys;
						
						// create join condition
						loc.condition = "";
						loc.jEnd = ListLen(loc.assoc.foreignKey);
						for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++) {
							
							// handle opposite join directions
							loc.keyA = ListGetAt(loc.listA, loc.j);
							loc.keyB = ListGetAt(loc.listB, loc.j);
							
							// set up equality between the two keys
							loc.columnA = StructKeyExists(loc.class.properties, loc.keyA) ? "#loc.tableA#." & loc.class.properties[loc.keyA].column : loc.class.calculatedProperties[loc.keyA].sql;
							loc.columnB = StructKeyExists(loc.otherClass.properties, loc.keyB) ? "#loc.tableB#." & loc.otherClass.properties[loc.keyB].column : loc.otherClass.calculatedProperties[loc.keyB].sql;
							loc.condition =  ListAppend(loc.condition, "#loc.columnA# = #loc.columnB#", Chr(7));
						}
						loc.condition = Replace(loc.condition, Chr(7), " AND ", "ALL");
				
						// if additional conditioning is specified, parse it out
						loc.condPos = Find("[", arguments.include, loc.pos);
						if (loc.condPos EQ loc.pos) {
							loc.pos = Find("]", arguments.include, loc.condPos + 1) + 1;
							loc.condition &= " AND " & Mid(arguments.include, loc.condPos + 1, loc.pos - loc.condPos - 2);
						}
						
						// call join on relation
						relation.join(loc.table, loc.condition, [], loc.assoc.joinType, true);
				}
			}
			
		</cfscript>
	</cffunction>
	
	<cffunction name="mapObject" returntype="void" access="public">
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
						
					// found a relation
					case "cfrel.Relation":
					
						// map all clauses in relation
						mapObject(arguments.obj.sql.select, arguments.useAlias);
						mapObject(arguments.obj.sql.joins, arguments.useAlias);
						mapObject(arguments.obj.sql.wheres, arguments.useAlias);
						mapObject(arguments.obj.sql.groups, arguments.useAlias);
						mapObject(arguments.obj.sql.havings, arguments.useAlias);
						mapObject(arguments.obj.sql.orders, arguments.useAlias);
						break;
					
					// found a column node
					case "cfrel.nodes.column":
					
						// map the column to the correct database column
						if (NOT StructKeyExists(arguments.obj, "mapping") AND Len(arguments.obj.table) EQ 0) {
							if (StructKeyExists(variables.columns, arguments.obj.column)) {
								if (arguments.useAlias AND arguments.obj.alias EQ "")
									arguments.obj.alias = arguments.obj.column;
								arguments.obj.mapping = variables.columns[arguments.obj.column];
							}
							
						// also try to map hard table names into aliases
						} else if (Len(arguments.obj.table)) {
							loc.iEnd = ArrayLen(variables.models);
							for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
								if (variables.models[loc.i].table EQ arguments.obj.table) {
									arguments.obj.table = variables.models[loc.i].alias;
									break;
								}
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
							if (StructKeyExists(arguments.obj, "condition"))
								mapObject(arguments.obj.condition, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "args"))
								mapObject(arguments.obj.args, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "scope"))
								mapObject(arguments.obj.scope, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "cases"))
								mapObject(arguments.obj.cases, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "els"))
								mapObject(arguments.obj.els, arguments.useAlias);
						}
				}
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="getLastTableAlias" returntype="string" access="public" hint="Search registered models for latest generated alias">
		<cfargument name="tableName" type="string" required="true" />
		<cfargument name="modelName" type="string" required="true" />
		<cfscript>
			var loc = {};
			for (loc.i = ArrayLen(variables.models); loc.i GT 0; loc.i--)
				if (variables.models[loc.i].table EQ arguments.tableName)
					return variables.models[loc.i].alias;
			return arguments.modelName;
		</cfscript>
	</cffunction>
</cfcomponent>