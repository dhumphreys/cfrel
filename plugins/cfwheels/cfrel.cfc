<cfcomponent output="false" mixin="model">
	
	<cffunction name="init" returntype="any" access="public">
		<cfscript>
			
			// set compatible Wheels version
			this.version = "1.1.1";
			
			// set up cfrel cfc mappings
			application.cfrel = {};
			application.cfrel.cfcPrefix = "plugins.cfrel.lib";
				
			return this;
		</cfscript>
	</cffunction>
	
	<!----------------------------
	--- Wheels Query Overrides ---
	----------------------------->
	
	<cffunction name="findAll" returntype="any" access="public" output="false">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false">
		<cfargument name="group" type="string" required="false">
		<cfargument name="having" type="string" required="false" default="">
		<cfargument name="select" type="string" required="false" default="">
		<cfargument name="distinct" type="boolean" required="false" default="false">
		<cfargument name="include" type="string" required="false" default="">
		<cfargument name="maxRows" type="numeric" required="false" default="-1">
		<cfargument name="page" type="numeric" required="false" default=0>
		<cfargument name="perPage" type="numeric" required="false">
		<cfargument name="count" type="numeric" required="false" default=0>
		<cfargument name="handle" type="string" required="false" default="query">
		<cfargument name="cache" type="any" required="false" default="">
		<cfargument name="reload" type="boolean" required="false">
		<cfargument name="parameterize" type="any" required="false">
		<cfargument name="returnAs" type="string" required="false">
		<cfargument name="returnIncluded" type="boolean" required="false">
		<cfargument name="callbacks" type="boolean" required="false" default="true">
		<cfargument name="includeSoftDeletes" type="boolean" required="false" default="false">
		<cfargument name="$limit" type="numeric" required="false" default=0>
		<cfargument name="$offset" type="numeric" required="false" default=0>
		<cfargument name="$orig" type="boolean" default="false">
		<cfscript>
			var loc = {};
			$args(name="findAll", args=arguments);
			
			// fall back to old findAll method
			if ($orig)
				return core.findAll(argumentCollection=arguments);

			// we only allow direct associations to be loaded when returning objects
			if (application.wheels.showErrorInformation && Len(arguments.returnAs) && arguments.returnAs != "query" && Find("(", arguments.include) && arguments.returnIncluded)
				$throw(type="Wheels", message="Incorrect Arguments", extendedInfo="You may only include direct associations to this object when returning an array of objects.");
			
			// return existing query result if it has been run already in current request, otherwise pass off the sql array to the query
			loc.queryKey = $hashedKey(variables.wheels.class.modelName, arguments, arguments.where);
			if (application.wheels.cacheQueriesDuringRequest AND NOT arguments.reload AND StructKeyExists(request.wheels, loc.queryKey)) {
				loc.rel = request.wheels[loc.queryKey];
				
			} else {
			
				// build new relation
				loc.rel = this.rel(parameterize=arguments.parameterize, includeSoftDeletes=arguments.includeSoftDeletes);
				
				// call portions of select
				if (Len(arguments.select) GT 0) loc.rel.select(arguments.select);
				if (arguments.distinct EQ true) loc.rel.distinct();
				if (Len(arguments.include) GT 0) loc.rel.include(arguments.include);
				if (Len(arguments.where) GT 0) loc.rel.where(arguments.where);
				if (Len(arguments.group) GT 0) loc.rel.group(arguments.group);
				if (Len(arguments.having) GT 0) loc.rel.having(arguments.having);
				if (Len(arguments.order) GT 0) loc.rel.order(arguments.order);
				if (arguments.page GT 0 AND StructKeyExists(arguments, "perPage"))
					loc.rel.paginate(arguments.page, arguments.perPage);
				if (arguments.maxRows GT 0) loc.rel.limit(arguments.maxRows);
				if (arguments.$limit GT 0) loc.rel.limit(arguments.$limit);
				if (arguments.$offset GT 0) loc.rel.offset(arguments.$offset);
				
				// ordering for paging (if no order specified)
				if (arguments.page AND Len(arguments.order) EQ 0)
					loc.rel.order(primaryKey());
					
				// execute query
				loc.rel.exec();
				
				// store in request cache so we never run the exact same query twice in the same request
				request.wheels[loc.queryKey] = loc.rel;
			}
			
			// get query results
			loc.query = loc.rel.query();
			
			// place an identifer in request scope so we can reference this query when passed in to view functions
			request.wheels[$hashedKey(loc.query)] = variables.wheels.class.modelName;
			
			// set pagination structure if needed
			if (arguments.page)
				setPagination(loc.rel.countTotalRecords(), arguments.page, arguments.perPage, arguments.handle);
			
			// if no records were found
			if (loc.query.recordCount EQ 0) {
				if (arguments.returnAs == "query")
					loc.returnValue = loc.query;
				else if (arguments.returnAs == "relation")
					loc.returnValue = loc.rel;
				else if (singularize(arguments.returnAs) == arguments.returnAs)
					loc.returnValue = false;
				else
					loc.returnValue = ArrayNew(1);
				
			} else {
				
				// return result in correct format
				switch (arguments.returnAs) {
					case "query":
						loc.returnValue = loc.query;
						// execute callbacks unless we're currently running the count or primary key pagination queries (we only want the callback to run when we have the actual data)
						if (loc.returnValue.columnList != "wheelsqueryresult" && !arguments.$limit && !arguments.$offset)
							$callback("afterFind", arguments.callbacks, loc.returnValue);
						break;
						
					case "relation":
						loc.returnValue = loc.rel;
						break;
						
					case "struct":
					case "structs":
						loc.returnValue = $serializeQueryToStructs(query=loc.query, argumentCollection=arguments);
						break;
						
					case "object":
					case "objects":
						loc.returnValue = $serializeQueryToObjects(query=loc.query, argumentCollection=arguments);
						break;
						
					default:
						if (application.wheels.showErrorInformation)
							$throw(type="Wheels.IncorrectArgumentValue", message="Incorrect Arguments", extendedInfo="The `returnAs` may be either `query`, `relation`, `struct(s)` or `object(s)`");
						break;
				}
			}
		</cfscript>
		<cfreturn loc.returnValue />
	</cffunction>
	
	<!--------------------
	--- Relation Calls ---
	--------------------->
	
	<cffunction name="rel" returntype="any" access="public" hint="Create relation object with this model as the subject">
		<cfargument name="parameterize" type="boolean" default="false" />includeSoftDeletes
		<cfargument name="includeSoftDeletes" type="boolean" default="false" />
		<cfscript>
			var loc = {};
			
			// determine visitor for relation
			if (NOT StructKeyExists(variables.wheels.class, "cfrelVisitor")) {
				loc.adapterMeta = GetMetaData($adapter());
				loc.visitor = ListLast(loc.adapterMeta.fullName, ".");
				switch (loc.visitor) {
					case "MicrosoftSQLServer": loc.visitor = "SqlServer"; break;
					case "MySQL": loc.visitor = "MySql"; break;
				}
				variables.wheels.class.cfrelVisitor = loc.visitor;
			}
			
			// create relation object
			loc.rel = CreateObject("component", "plugins.cfrel.lib.Relation");
			loc.rel.init(
				datasource=variables.wheels.class.connection.datasource,
				visitor=variables.wheels.class.cfrelVisitor,
				mapper="CFWheels",
				argumentCollection=arguments
			);
			loc.rel.from(this);
			
			return loc.rel;
		</cfscript>
	</cffunction>
	
	<cffunction name="select" returntype="any" access="public" hint="Append columns to SELECT clause">
		<cfreturn this.rel().select(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="distinct" returntype="any" access="public" hint="Make a relation DISTINCT">
		<cfreturn this.rel().distinct(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="join" returntype="any" access="public" hint="Add a JOIN clause">
		<cfreturn this.rel().join(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="include" returntype="any" access="public" hint="Use model associations to build JOIN clauses">
		<cfreturn this.rel().include(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="where" returntype="any" access="public" hint="Append conditions to WHERE clause">
		<cfreturn this.rel().where(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="group" returntype="any" access="public" hint="Append columns to GROUP BY clause">
		<cfreturn this.rel().group(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="having" returntype="any" access="public" hint="Append conditions to HAVING clause">
		<cfreturn this.rel().having(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="order" returntype="any" access="public" hint="Append orderings to ORDER BY clause">
		<cfreturn this.rel().order(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="limit" returntype="any" access="public" hint="Limit rows returned using the LIMIT clause">
		<cfreturn this.rel().limit(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="offset" returntype="any" access="public" hint="Skip records using the OFFSET clause">
		<cfreturn this.rel().offset(argumentCollection=arguments) />
	</cffunction>
	
	<cffunction name="paginate" returntype="any" access="public" hint="Use page number and size to set LIMIT and OFFSET">
		<cfreturn this.rel().paginate(argumentCollection=arguments) />
	</cffunction>
</cfcomponent>