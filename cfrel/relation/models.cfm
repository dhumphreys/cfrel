<cffunction name="getModels" returntype="array" access="public" hint="Return array of all models involved in query">
	<cfargument name="stack" type="array" default="#[]#" />
	<cfscript>
		var loc = {};
		
		// add models from FROM clause
		loc.iEnd = ArrayLen(this.sql.froms);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
			loc.fromType = typeOf(this.sql.froms[loc.i]);
			if (loc.fromType EQ "cfrel.Relation")
				arguments.stack = this.sql.froms[loc.i].getModels(arguments.stack);
			else if (loc.fromType EQ "cfrel.nodes.Table" AND IsObject(this.sql.froms[loc.i].model))
				ArrayAppend(arguments.stack, this.sql.froms[loc.i]);
		}
			
		// add models from JOIN clauses
		loc.iEnd = ArrayLen(this.sql.joins);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			if (IsObject(this.sql.joins[loc.i].table.model))
				ArrayAppend(arguments.stack, this.sql.joins[loc.i].table);
		
		return arguments.stack;
	</cfscript>
</cffunction>

<cffunction name="_applyMappings" returntype="void" access="public" hint="Use Mapper to map model columns to database columns">
	<cfscript>
		if (NOT variables.mapped) {
			
			// map any subquery relations
			loc.iEnd = ArrayLen(this.sql.froms);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				if (typeOf(this.sql.froms[loc.i]) EQ "cfrel.Relation")
					this.sql.froms[loc.i]._applyMappings();
			
			// default to a wildcard selector
			if (ArrayLen(this.sql.select) EQ 0)
				ArrayAppend(this.sql.select, sqlWildcard());
				
			// map the relation columns
			this.mapper.mapObject(this);
			variables.mapped = true;
		}
	</cfscript>
</cffunction>
