<cfcomponent extends="Mapper" displayName="CFWheels" output="false">
	<cfinclude template="#application.wheels.rootPath#/wheels/global/functions.cfm" />
	
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
			loc.model = model(arguments.table.model).$classData();

			// determine correct base table alias
			loc.alias = Len(arguments.table.alias) ? arguments.table.alias : arguments.table.model;

			// look up table information and associate it with an alias
			loc.table = StructNew();
			loc.table.table = loc.model.tableName;
			loc.table.modelName = loc.model.modelName;
			loc.table.alias = uniqueScopeKey(key=loc.alias, scope=arguments.map.tables);
			loc.table.properties = StructNew();
			loc.table.calculatedProperties = StructNew();
			loc.table.primaryKey = loc.model.keys;
		
			// if the option is set, and the model has soft delete, consider it in the WHERE clause
			if (NOT arguments.table.includeSoftDeletes AND loc.model.softDeletion)
				loc.table.softDelete = sqlBinaryOp(sqlColumn(loc.table.alias & "." & loc.model.softDeleteColumn), "IS", "NULL");
			else
				loc.table.softDelete =  false;

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
				loc.col.alias = uniqueScopeKey(key=loc.key, prefix=loc.table.modelName, scope=arguments.map.columns);
				loc.col.mapping = "#loc.col.table#.#loc.col.column#";
				loc.col.cfsqltype = loc.model.properties[loc.key].type;
				loc.col.calculated = false;

				// create unique mappings for [alias], [table].[alias], and [table].[property]
				arguments.map.columns[loc.col.alias] = loc.col;
				arguments.map.columns["#loc.col.table#.#loc.col.alias#"] = loc.col;
				if (NOT StructKeyExists(arguments.map.columns, "#loc.col.table#.#loc.col.property#"))
					arguments.map.columns["#loc.col.table#.#loc.col.property#"] = loc.col;

				// add to property list for table mapping
				loc.table.properties[loc.col.property] = loc.col;
			}

			// look up calculated properties and associate them with an alias
			for (loc.key in loc.model.calculatedProperties) {
				loc.col = StructNew();
				loc.col.property = loc.key;
				loc.col.alias = uniqueScopeKey(key=loc.key, prefix=loc.table.modelName, scope=arguments.map.columns);
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

		</cfscript>
		<cfreturn arguments.map />
	</cffunction>

	<cffunction name="mapInclude" returntype="struct" access="public" hint="Map include nodes using CFWheels association data">
		<cfargument name="relation" type="any" required="true" />
		<cfargument name="include" type="any" required="true" />
		<cfargument name="map" type="struct" default="#emptyMap()#" />
		<cfscript>
			var loc = {};
			loc.joins = ArrayNew(1);
			loc.associationMappings = StructNew();

			// look up data on FROM model for the relation
			// TODO: use last `from` in list and operate on from[last].joins
			loc.base = StructNew();
			loc.base.model = arguments.relation.sql.froms[1].model;
			loc.base.associations = model(loc.base.model).$classData().associations;
			loc.base.alias = arguments.map.aliases[loc.base.model][1];
			loc.base.mapping = arguments.map.tables[loc.base.alias];

			// loop over every join in the tree
			for (loc.key in arguments.include.tree.order) {

				// skip joins already completed for this include statement
				if (StructKeyExists(loc.associationMappings, loc.key))
					continue;

				// extract name of association and it's parent
				loc.currKey = ListLast(loc.key, "_");
				loc.parentKey = ListDeleteAt(loc.key, ListLen(loc.key, "_"), "_");

				// reference data for the model we want to join from (default to FROM model)
				loc.parent = (loc.parentKey EQ "") ?  loc.base : loc.associationMappings[loc.parentKey];

				// look up association and map table information from the parent
				if (NOT StructKeyExists(loc.parent.associations, loc.currKey))
					throwException("Association `#loc.currKey#` not found in model `#loc.parent.mapping.modelName#`.");
				loc.assoc = loc.parent.associations[loc.currKey];
				loc.table = sqlModel(model=loc.assoc.modelName, includeSoftDeletes=arguments.include.includeSoftDeletes);

				// map the table we want to join and append to current mappings
				arguments.map = mapTable(loc.table, arguments.map);

				// look up data for the association we want to join to
				loc.curr = StructNew();
				loc.curr.model = model(loc.table.model);
				loc.curr.associations = loc.curr.model.$classData().associations;
				loc.curr.alias = arrayLast(arguments.map.aliases[loc.curr.model.$classData().modelName]);
				loc.curr.mapping = arguments.map.tables[loc.curr.alias];

				// store the association structure in a location other joins in this same include can read from
				loc.associationMappings[loc.key] = loc.curr;
						
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
						loc.assoc.joinKey = loc.parent.mapping.primaryKey;
					if (loc.assoc.foreignKey EQ "")
						loc.assoc.foreignKey = REReplace(loc.parent.mapping.primaryKey, "(^|,)", "\1" & loc.parent.mapping.modelName, "ALL");

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
					if (StructKeyExists(loc.parent.mapping.properties, loc.keyA))
						loc.columnA = loc.parent.mapping.alias & "." & loc.parent.mapping.properties[loc.keyA].column;
					else if (StructKeyExists(loc.parent.mapping.calculatedProperties, loc.keyA))
						loc.columnA = loc.parent.mapping.calculatedProperties[loc.keyA].sql;
					else
						throwException("Property `#loc.keyA#` not found in model `#loc.parent.mapping.modelName#`.");
					
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
				if (StructKeyExists(arguments.include.tree.options[loc.key], "condition"))
					ArrayAppend(loc.condition, arguments.include.tree.options[loc.key].condition);

				// condense conditions into a single tree
				while (ArrayLen(loc.condition) GT 1) {
					loc.condition[2] = sqlBinaryOp(left=loc.condition[1], op="AND", right=loc.condition[2]);
					ArrayDeleteAt(loc.condition, 1);
				}
				
				// use the passed in join type, or the default for this association
				loc.joinType = (arguments.include.tree.options[loc.key].joinType EQ "") ? loc.assoc.joinType : arguments.include.tree.options[loc.key].joinType;
				
				// join to the table
				loc.join = sqlJoin(loc.table, ArrayLen(loc.condition) ? loc.condition[1] : false, loc.joinType);
				ArrayAppend(loc.joins, loc.join);
			}

			// store all new joins with their unique 'includeKey' for later mapping
			arguments.map.includes[arguments.include.includeKey] = loc.joins;

			return arguments.map;
		</cfscript>
	</cffunction>
	
	<cffunction name="scopes" returntype="any" access="public">
		<cfargument name="modelName" type="any" required="true" />
		<cfreturn model(arguments.modelName).scopes() />
	</cffunction>
	
	<cffunction name="primaryKey" returntype="string" access="public" hint="Get primary key list from model">
		<cfargument name="modelName" type="any" required="true" />
		<cfreturn model(arguments.modelName).primaryKey() />
	</cffunction>
	
	<cffunction name="beforeFind" returntype="void" access="public" hint="Do before-find relation logic">
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// if recordset is paged, set up ordering like cfwheels
			// TODO: we are not making sure that all primary key fields are in the order clause here
			if (arguments.relation.isPaged() AND arguments.relation.model NEQ false AND ArrayLen(arguments.relation.sql.orders) EQ 0) {
				
				// add the primary keys to the order list
				arguments.relation.order(primaryKey(arguments.relation.model));
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="afterFind" returntype="query" access="public" hint="Do after-find query processing">
		<cfargument name="modelName" type="any" required="true" />
		<cfargument name="query" type="query" required="true" />
		<cfscript>
			model(arguments.modelName).$callback("afterFind", true, arguments.query);
			return arguments.query;
		</cfscript>
	</cffunction>
	
</cfcomponent>