<cffunction name="paginate" returntype="struct" access="public" hint="Calculate LIMIT and OFFSET with page number and per-page constraint">
	<cfargument name="page" type="numeric" required="true" />
	<cfargument name="perPage" type="numeric" required="true" />
	<cfscript>
		if (variables.executed)
			return this.clone().paginate(argumentCollection=arguments);
		
		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), arguments);
			
		// throw error if bad values are passed
		if (arguments.page LT 1 OR arguments.perPage LT 1)
			throwException("Page and per-page must be greater than zero");
		
		// calculate limit and offset
		this.sql.limit = Int(arguments.perPage);
		this.sql.offset = (Int(arguments.page) - 1) * this.sql.limit;
		
		// set variable showing this is paged
		variables.paged = true;
		
		return this;
	</cfscript>
</cffunction>

<cffunction name="isPaged" returntype="boolean" access="public" hint="Return whether or not query is paged">
	<cfreturn variables.paged />
</cffunction>

<cffunction name="clearPagination" returntype="struct" access="public" hint="Remove all limits, offsets, and pagination from the current relation">
	<cfscript>
		if (variables.executed)
			return this.clone().clearPagination(argumentCollection=arguments);
		
		if (variables.cacheSql)
			removeFromSignature({"paginate"=1,"limit"=1,"offset"=1});

		// remove limits and offsets
		if (StructKeyExists(this.sql, "limit"))
			StructDelete(this.sql, "limit");
		if (StructKeyExists(this.sql, "offset"))
			StructDelete(this.sql, "offset");
		
		// reset max rows variable
		this.maxRows = 0;
		
		// unset variable showing this is paged
		variables.paged = false;
		
		return this;
	</cfscript>
</cffunction>

<cffunction name="minimizedRelation" returntype="struct" access="public" hint="Return a new relation without aggregate selects">
	<cfscript>
		var loc = {};
		
		// clone query
		loc.rel = this.clone();
		
		// eliminate aggregates from count if using GROUP BY
		if (ArrayLen(this.sql.groups) GT 0) {
				
			// make query distinct
			loc.rel.distinct();
			
			// use GROUP BY as SELECT
			loc.rel.sql.select = Duplicate(loc.rel.sql.groups);
		}
		
		// make sure select columns have aliases
		loc.iEnd = ArrayLen(loc.rel.sql.select);
		for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
			if (ListFindNoCase("Column,Alias,Literal,Wildcard", ListLast(typeOf(loc.rel.sql.select[loc.i]), ".")) EQ 0)
				loc.rel.sql.select[loc.i] = sqlAlias(subject=loc.rel.sql.select[loc.i], alias="countColumn#loc.i#");
				
		return loc.rel;
	</cfscript>
</cffunction>

<cffunction name="countRelation" returntype="struct" access="public" hint="Create relation to calculate number of records that would be returned if pagination was not used">
	<cfscript>
		var loc = {};
		
		// get back a relation with only columns needed
		loc.rel = this.minimizedRelation();
		
		// remove order by and paging since we just care about count
		loc.rel.clearOrder();
		loc.rel.clearPagination();
				
		// create new relation to contain subquery
		loc.rel2 = relation(datasource=this.datasource, visitor=variables.visitorClass);
		loc.rel2.select(sqlLiteral("COUNT(*) AS numberOfRows"));
		loc.rel2.from(loc.rel);
		
		return loc.rel2;
	</cfscript>
</cffunction>

<cffunction name="countTotalRecords" returntype="numeric" access="public" hint="Calculate number of records that would be returned if pagination was not used">
	<cfreturn this.countRelation().query().numberOfRows />
</cffunction>