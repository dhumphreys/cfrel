<cfcomponent output="false" mixin="model">

	<!--- TODO: Move this to a place where it can be used without CFWheels --->
	<cffunction name="init" returntype="any" access="public">
		<cfscript>
			
			// set compatible Wheels version
			this.version = "1.1,1.1.1,1.1.2,1.1.3,1.1.4,1.1.5";

			// create a Java Concurrent object proxies to use for application-level concurrency of application.cfrel and application.cfrel caches
			var concurrentHashMapProxy = CreateObject("java", "java.util.concurrent.ConcurrentHashMap");
			var concurrentLinkedQueue = CreateObject("java", "java.util.concurrent.ConcurrentLinkedQueue");
			
			// set up cfrel cfc mappings
			application.cfrel = {};
			application.cfrel.cfcPrefix = "plugins.cfrel.lib";

			Application.cfrel.HASH_ALGORITHM = "MD5";

			Application.cfrel.allowCaching = true;

			// create caches and cache info structures
			Application.cfrel.cache = concurrentHashMapProxy.init();
			for (var cacheName in ["parse", "map", "sql", "signatureHash"]) {
				Application.cfrel.cache[cacheName] = concurrentHashMapProxy.init();
				Application.cfrel.cacheSizeSamples[cacheName] = concurrentLinkedQueue.init();
			}

			// link some java proxies to application scope for better performance in cfrel
			application.cfrel.javaProxies.concurrentLinkedQueue = concurrentLinkedQueue;
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
		<cfargument name="parameterize" type="any" default="true">
		<cfargument name="returnAs" type="string" required="false">
		<cfargument name="returnIncluded" type="boolean" required="false">
		<cfargument name="callbacks" type="boolean" required="false" default="true">
		<cfargument name="includeSoftDeletes" type="boolean" required="false" default="false">
		<cfargument name="useDefaultScope" type="boolean" required="false" default="#$useDefaultScope()#">
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
			if (application.wheels.showErrorInformation && Len(arguments.returnAs) && ListFindNoCase("query,relation", arguments.returnAs) == 0 && Find("(", arguments.include) && arguments.returnIncluded)
				$throw(type="Wheels", message="Incorrect Arguments", extendedInfo="You may only include direct associations to this object when returning an array of objects.");
			
			// return existing query result if it has been run already in current request, otherwise pass off the sql array to the query
			loc.queryKey = $hashedKey(variables.wheels.class.modelName, arguments, arguments.where);
			if (application.wheels.cacheQueriesDuringRequest AND NOT arguments.reload AND StructKeyExists(request.wheels, loc.queryKey)) {
				loc.rel = request.wheels[loc.queryKey];
				
			} else {
			
				// build new relation
				loc.rel = this.rel(
					parameterize=arguments.parameterize,
					includeSoftDeletes=arguments.includeSoftDeletes,
					useDefaultScope=arguments.useDefaultScope
				);
				
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
					
				// execute query
				loc.rel.exec(callbacks=arguments.callbacks);
				
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
	
	<cffunction name="findOne" returntype="any" access="public" output="false">
		<cfargument name="where" type="string" required="false" default="">
		<cfargument name="order" type="string" required="false" default="">
		<cfargument name="select" type="string" required="false" default="">
		<cfargument name="include" type="string" required="false" default="">
		<cfargument name="cache" type="any" required="false" default="">
		<cfargument name="reload" type="boolean" required="false">
		<cfargument name="parameterize" type="any" required="false">
		<cfargument name="returnAs" type="string" required="false">
		<cfargument name="includeSoftDeletes" type="boolean" required="false" default="false">
		<cfargument name="useDefaultScope" type="boolean" required="false" default="false">
		<cfscript>
			// make sure that all findOne calls don't use default scope
			var coreMethod = core.findOne;
			return coreMethod(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<!------------
	-- Scoping ---
	------------->
	
	<cffunction name="defaultScope" returntype="void" access="public" hint="Set relation or callback to be default scope for this model">
		<cfargument name="scope" type="any" required="true" hint="Method or text to evaluate" />
		<cfset variables.scope("default", arguments.scope) />
	</cffunction>
	
	<cffunction name="scope" returntype="void" access="public" hint="Set relation or callback to be a named scope for this model">
		<cfargument name="name" type="string" required="true" hint="Name of scope method to create" />
		<cfargument name="scope" type="any" required="true" hint="Method or text to evaluate" />
		<cfset scopes()[arguments.name] = arguments.scope />
	</cffunction>
	
	<cffunction name="unscoped" returntype="any" access="public" hint="Return a relation that does not have default scope applied">
		<cfargument name="parameterize" type="boolean" default="false" />
		<cfargument name="includeSoftDeletes" type="boolean" default="false" />
		<cfreturn rel(argumentCollection=arguments, useDefaultScope=false) />
	</cffunction>
	
	<cffunction name="scopes" returntype="struct" access="public">
		<cfscript>
			if (NOT StructKeyExists(variables.wheels.class, "scopes"))
				variables.wheels.class.scopes = {};
			return variables.wheels.class.scopes;
		</cfscript>
	</cffunction>
	
	<cffunction name="$evaluateScope" returntype="struct" access="public">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="args" type="struct" default="#structNew()#" />
		<cfscript>
			var $customScope = scopes()[arguments.name];
			var loc = {};
			loc.defaultScope = arguments.name EQ "default";
			try {
				
				// if calling default scope, disable the default scope for the next operation
				if (loc.defaultScope)
					variables.wheels.class.useDefaultScope = false;
					
				// evaluate scope based on variable type
				if (IsCustomFunction($customScope))
					loc.rtn = $customScope(argumentCollection=arguments.args);
				else if (IsSimpleValue($customScope))
					loc.rtn = Evaluate($customScope);
				else
					loc.rtn = rel();
				
			} finally {
				
				// re-enable default scope
				if (loc.defaultScope)
					variables.wheels.class.useDefaultScope = true;
			}
			return loc.rtn;
		</cfscript>
	</cffunction>
	
	<cffunction name="$useDefaultScope" returntype="boolean" access="public">
		<cfscript>
			if (NOT StructKeyExists(variables.wheels.class, "useDefaultScope"))
				variables.wheels.class.useDefaultScope = true;
			return variables.wheels.class.useDefaultScope;
		</cfscript>
	</cffunction>
	
	<!--------------------
	--- Relation Calls ---
	--------------------->
	
	<cffunction name="rel" returntype="any" access="public" hint="Create relation object with this model as the subject">
		<cfargument name="parameterize" type="boolean" default="false" />
		<cfargument name="includeSoftDeletes" type="boolean" default="false" />
		<cfargument name="useDefaultScope" type="boolean" default="#$useDefaultScope()#" />
		<cfargument name="cacheParse" type="boolean" default="true" />
		<cfargument name="cacheMap" type="boolean" default="true" />
		<cfargument name="cacheSql" type="boolean" default="true" />
		<cfscript>
			var loc = {};
			
			// if using default scope, just return it
			if (arguments.useDefaultScope AND StructKeyExists(scopes(), "default"))
				return $evaluateScope("default");
			
			// determine visitor for relation
			if (NOT StructKeyExists(variables.wheels.class, "cfrelVisitor")) {
				loc.adapterMeta = GetMetaData(variables.wheels.class.adapter);
				loc.visitor = ListLast(loc.adapterMeta.fullName, ".");
				switch (loc.visitor) {
					case "MicrosoftSQLServer": loc.visitor = "SqlServer"; break;
					case "MySQL": loc.visitor = "MySql"; break;
					case "PostgreSQL": loc.visitor = "PostgreSql"; break;
					default: loc.visitor = "Sql";
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
	
	<cffunction name="selectGroup" returntype="any" access="public" hint="Append columns to SELECT and GROUP BY clause">
		<cfreturn this.rel().selectGroup(argumentCollection=arguments) />
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
	
	<!-----------------------------
	--- Missing Method Handling ---
	------------------------------>
	
	<cffunction name="onMissingMethod" returntype="any" access="public" output="false">
		<cfargument name="missingMethodName" type="string" required="true" />
		<cfargument name="missingMethodArguments" type="struct" required="true" />
		<cfscript>
			var coreMethod = core.onMissingMethod;
			
			// if the method name is a custom scope, evaluate that scope
			if (StructKeyExists(scopes(), arguments.missingMethodName))
				return $evaluateScope(arguments.missingMethodName, arguments.missingMethodArguments);
				
			// call original cfwheels missing method
			return coreMethod(argumentCollection=arguments);
		</cfscript>
	</cffunction>
</cfcomponent>