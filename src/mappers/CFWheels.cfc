<cfcomponent extends="Mapper" displayName="CFWheels" output="false">
	
	<cffunction name="buildMapping" returntype="void" access="public">
		<cfargument name="table" type="any" required="true" />
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			var loc = {};
			
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
				loc.colData = {};
				
				// TODO: a bug here will cause multiple joins on the same table to generate
				// errors with calculated properties out of ambiguous column names
			
				// handle ambiguous columns for single table calculated properties
				loc.colData.value = REReplace(loc.col.sql, ":TABLE\b", loc.tableAlias, "ALL");
					
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
		<cfargument name="joinType" type="string" default="" />
		<cfscript>
			var loc = {};
			
			// get last FROM item
			loc.from = relation.sql.froms[ArrayLen(relation.sql.froms)];
			
			// throw error if FROM is not a model
			if (typeOf(loc.from.model) NEQ "model")
				throwException("Includes can only be used with models");
				
			// set up control stacks
			loc.modelStack = [loc.from.model];
			loc.aliasStack = [loc.from.alias];
			loc.includeStack = [variables.includes];
			
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
						ArrayPrepend(loc.modelStack, loc.associationModel);
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
						
						// look up class data for current model
						loc.class = loc.modelStack[1].$classData();
						
						// look up association
						// TODO: catch for missing associations
						loc.assoc = loc.class.associations[loc.key];
						loc.associationModel = loc.from.model.model(loc.assoc.modelName);
						loc.associationClass = loc.associationModel.$classData();
						
						// only join to the association if it was not previously included
						if (NOT StructKeyExists(loc.includeStack[1], loc.key)) {
							loc.includeStack[1][loc.key] = javaHash();
					
							// build mapping for current model
							loc.associationTable = sqlTable(model=loc.associationModel);
							buildMapping(loc.associationTable, arguments.relation);
							
							// determine table aliases to use
							loc.modelAlias = loc.aliasStack[1];
							loc.includeStack[1][loc.key]["_alias"] = loc.associationTable.alias;
							
							// determine join keys to use
							if (loc.assoc.type EQ "belongsTo") {
								
								// guess join key if not set
								if (NOT StructKeyExists(loc.assoc, "joinKey") OR loc.assoc.joinKey EQ "")
									loc.assoc.joinKey = loc.associationClass.keys;
								 
								// guess foreign key if not set
								if (loc.assoc.foreignKey EQ "")
									loc.assoc.foreignKey = REReplace(loc.associationClass.keys, "(^|,)", "\1#loc.associationClass.modelName#", "ALL");
									
								// set keys in reverse order
								loc.listA = loc.assoc.foreignKey;
								loc.listB = loc.assoc.joinKey;
								
							} else {
								
								// guess join key if not set
								if (NOT StructKeyExists(loc.assoc, "joinKey") OR loc.assoc.joinKey EQ "")
									loc.assoc.joinKey = loc.class.keys;
									
								// guess foreign key if not set
								if (loc.assoc.foreignKey EQ "")
									loc.assoc.foreignKey = REReplace(loc.class.keys, "(^|,)", "\1#loc.class.modelName#", "ALL");
									
								// set keys in regular order
								loc.listA = loc.assoc.joinKey;
								loc.listB = loc.assoc.foreignKey;
							}
							
							// create join condition
							loc.condition = "";
							loc.jEnd = ListLen(loc.assoc.foreignKey);
							for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++) {
								
								// handle opposite join directions
								loc.keyA = ListGetAt(loc.listA, loc.j);
								loc.keyB = ListGetAt(loc.listB, loc.j);
								
								// set up equality between the two keys
								loc.columnA = StructKeyExists(loc.class.properties, loc.keyA) ? "#loc.modelAlias#." & loc.class.properties[loc.keyA].column : loc.class.calculatedProperties[loc.keyA].sql;
								loc.columnB = StructKeyExists(loc.associationClass.properties, loc.keyB) ? "#loc.includeStack[1][loc.key]['_alias']#." & loc.associationClass.properties[loc.keyB].column : loc.associationClass.calculatedProperties[loc.keyB].sql;
								loc.condition =  ListAppend(loc.condition, "#loc.columnB# = #loc.columnA#", Chr(7));
							}
							loc.condition = Replace(loc.condition, Chr(7), " AND ", "ALL");
					
							// if additional conditioning is specified, parse it out
							loc.condPos = Find("[", arguments.include, loc.pos);
							if (loc.condPos EQ loc.pos) {
								loc.pos = Find("]", arguments.include, loc.condPos + 1) + 1;
								loc.condition &= " AND " & Mid(arguments.include, loc.condPos + 1, loc.pos - loc.condPos - 2);
							}
							
							// use the passed in join type, or the default for this association
							loc.joinType = (arguments.joinType EQ "") ? loc.assoc.joinType : arguments.joinType;
							
							// call join on relation
							relation.join(loc.associationTable, loc.condition, [], loc.joinType, true);
						}
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
						arguments.obj.mapping = wildcardColumns(arguments.obj.subject);
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
							if (StructKeyExists(arguments.obj, "start"))
								mapObject(arguments.obj.start, arguments.useAlias);
							if (StructKeyExists(arguments.obj, "end"))
								mapObject(arguments.obj.end, arguments.useAlias);
						}
				}
			}
		</cfscript>
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
	
	<cffunction name="primaryKey" returntype="array" access="public" hint="Get primary key array from model">
		<cfargument name="model" type="any" required="true" />
		<cfscript>
			if (IsObject(arguments.model))
				return ListToArray(arguments.model.primaryKey());
			return ArrayNew(1);
		</cfscript>
	</cffunction>
	
</cfcomponent>