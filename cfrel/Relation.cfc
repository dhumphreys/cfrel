<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfargument name="datasource" type="string" default="" />
		<cfargument name="visitor" type="string" default="Sql" />
		<cfargument name="mapper" type="string" default="Mapper" />
		<cfscript>
			
			// datasource and visitor to use
			this.datasource = arguments.datasource;
			this.visitor = CreateObject("component", "cfrel.visitors.#arguments.visitor#").init();
			this.mapper = CreateObject("component", "cfrel.mappers.#arguments.mapper#").init();
			
			// struct to hold SQL tree
			this.sql = {
				select = [],
				selectFlags = [],
				joins = [],
				joinParameters = [],
				wheres = [],
				whereParameters = [],
				groups = [],
				havings = [],
				havingParameters = [],
				orders = []
			};
			
			// internal control and value variables
			variables.query = false;
			variables.result = false;
			variables.executed = false;
			variables.mapped = false;
			variables.qoq = false;
			variables.paged = false;
			variables.paginationData = false;
			
			// internal parser
			variables.parser = CreateObject("component", "cfrel.Parser").init();
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="new" returntype="struct" access="public" hint="Create new instance of relation">
		<cfscript>
			return relation(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="clone" returntype="struct" access="public" hint="Duplicate the relation object">
		<cfscript>
			var loc = {};
			
			// duplicate object and sql
			loc.rel = Duplicate(this);
			loc.rel.sql = StructCopy(this.sql);
			loc.rel.executed = false;
			
			// remove query values that should not be kept in new instance
			if (variables.executed EQ true OR IsObject(variables.query)) {
				loc.private = injectInspector(loc.rel)._inspect();
				loc.private.query = false;
				loc.private.result = false;
				loc.private.executed = false;
				loc.private.mapped = false;
			}
			
			// remove pagination variables
			if (variables.paged EQ true) {
				loc.private = injectInspector(loc.rel)._inspect();
				loc.private.paginationData = false;
			}
			
			return loc.rel;
		</cfscript>
	</cffunction>
	
	<cffunction name="select" returntype="struct" access="public" hint="Append to the SELECT clause of the relation">
		<cfscript>
			if (variables.executed)
				return this.clone().select(argumentCollection=arguments);
				
			_appendFieldsToClause("SELECT", "select", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="distinct" returntype="struct" access="public" hint="Set DISTINCT flag for SELECT">
		<cfscript>
			if (variables.executed)
				return this.clone().distinct(argumentCollection=arguments);
				
			if (NOT ArrayFind(this.sql.selectFlags, "DISTINCT"))
				ArrayAppend(this.sql.selectFlags, "DISTINCT");
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="from" returntype="struct" access="public" hint="Specify FROM target of either a table or another relation">
		<cfargument name="target" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// auto-clone if relation already executed
			if (variables.executed)
				return this.clone().from(argumentCollection=arguments);
			
			// make decision based on argument type
			switch(typeOf(arguments.target)) {
				
				// accept relations, models, and stings
				case "cfrel.Relation":
					this.sql.from = arguments.target;
					break;
					
				case "model":
					this.sql.from = sqlTable(model=arguments.target);
					break;
					
				case "simple":
					this.sql.from = sqlTable(arguments.target);
					break;
				
				// accept queries for QoQ operations
				case "query":
					this.sql.from = arguments.target;
					variables.qoq = true;
					break;
					
				// and reject all others by throwing an error
				default:
					throwException("Only a table name or another relation can be in FROM clause");
			}
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="include" returntype="struct" access="public" hint="Add a JOIN to the relation using predefined relationships">
		<cfscript>
			if (variables.executed)
				return this.clone().include(argumentCollection=arguments);
				
			// make sure a from has been specified
			if (NOT StructKeyExists(this.sql, "from"))
				throwException("Includes cannot be specified before FROM clause");
				
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="join" returntype="struct" access="public" hint="Add a JOIN to the relation">
		<cfargument name="target" type="any" required="true" />
		<cfargument name="condition" type="any" default="false" />
		<cfargument name="params" type="array" default="#[]#" />
		<cfargument name="type" type="string" default="inner" hint="INNER or OUTER join" />
		<cfscript>
			var loc = {};
			if (variables.executed)
				return this.clone().join(argumentCollection=arguments);
				
			// correctly set condition
			if (typeOf(arguments.condition) NEQ "simple")
				loc.condition = arguments.condition;
			else if (arguments.condition NEQ false)
				loc.condition = variables.parser.parse(arguments.condition);
			else
				loc.condition = false;
				
			// create table object
			switch(typeOf(arguments.target)) {
				
				// assume simple values are names
				case "simple":
					loc.table = sqlTable(arguments.target);
					break;
					
				// just use raw table object
				case "cfrel.nodes.table":
					loc.table = arguments.target;
					break;
					
				// throw error if invalid target
				default:
					throwException("Only table names or table nodes can be target of JOIN");
					
			}
			
			// append join to sql structure
			ArrayAppend(this.sql.joins, sqlJoin(loc.table, loc.condition, arguments.type));
			
			// handle parameters for join
			loc.iEnd = ArrayLen(arguments.params);
			for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
				ArrayAppend(this.sql.joinParameters, arguments.params[loc.i]);
				
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="where" returntype="struct" access="public" hint="Append to the WHERE clause of the relation">
		<cfargument name="$clause" type="any" required="false" />
		<cfargument name="$params" type="array" required="false" />
		<cfscript>
			if (variables.executed)
				return this.qoq().where(argumentCollection=arguments);
				
			_appendConditionsToClause("WHERE", "wheres", "whereParameters", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="group" returntype="struct" access="public" hint="Append to GROUP BY clause of the relation">
		<cfscript>
			if (variables.executed)
				return this.clone().group(argumentCollection=arguments);
				
			_appendFieldsToClause("GROUP BY", "groups", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="having" returntype="struct" access="public" hint="Append to HAVING clause of the relation">
		<cfargument name="$clause" type="any" required="false" />
		<cfargument name="$params" type="array" required="false" />
		<cfscript>
			if (variables.executed)
				return this.clone().having(argumentCollection=arguments);
				
			_appendConditionsToClause("HAVING", "havings", "havingParameters", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="order" returntype="struct" access="public" hint="Append to ORDER BY clause of the relation">
		<cfscript>
			if (variables.executed)
				return this.clone().order(argumentCollection=arguments);
				
			_appendFieldsToClause("ORDER BY", "orders", arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="limit" returntype="struct" access="public" hint="Restrict the number of records when querying">
		<cfargument name="value" type="numeric" required="true" />
		<cfscript>
			if (variables.executed)
				return this.clone().limit(argumentCollection=arguments);
				
			this.sql.limit = Int(arguments.value);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="offset" returntype="struct" access="public" hint="Skip some records when querying">
		<cfargument name="value" type="numeric" required="true" />
		<cfscript>
			if (variables.executed)
				return this.clone().offset(argumentCollection=arguments);
				
			this.sql.offset = Int(arguments.value);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="paginate" returntype="struct" access="public" hint="Calculate LIMIT and OFFSET with page number and per-page constraint">
		<cfargument name="page" type="numeric" required="true" />
		<cfargument name="perPage" type="numeric" required="true" />
		<cfscript>
			if (variables.executed)
				return this.clone().paginate(argumentCollection=arguments);
			
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
	
	<cffunction name="toSql" returntype="string" access="public" hint="Convert relational data into a SQL string">
		<cfscript>
			if (ArrayLen(this.sql.select) EQ 0)
				ArrayAppend(this.sql.select, sqlWildcard());
			
			// map columns
			if (NOT variables.mapped) {
				this.mapper.clearMapping();
				this.mapper.buildMapping(this);
				this.mapper.applyMapping(this);
				variables.mapped = true;
			}
			
			return this.visitor.visit(this);
		</cfscript>
	</cffunction>
	
	<cffunction name="exec" returntype="struct" access="public" hint="Run query() but return the relation">
		<cfscript>
			this.query();
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="reload" returntype="struct" access="public" hint="Execute again to reload dataset">
		<cfscript>
			variables.executed = false;
			return this.exec();
		</cfscript>
	</cffunction>
	
	<cffunction name="qoq" returntype="struct" access="public" hint="Return a QoQ relation with the current recordset as the FROM">
		<cfreturn this.new().from(this.query()) />
	</cffunction>
	
	<cffunction name="query" returntype="query" access="public" hint="Lazily execute and return query object">
		<cfscript>
			var loc = {};
			
			// drop into query logic if we don't have a query yet
			if (variables.executed EQ false OR NOT IsQuery(variables.query)) {
					
				// create the new query object
				loc.query = new query();
				
				// if we are using query of a query, set dbtype and resultset
				if (variables.qoq) {
					loc.query.setAttributes(dbType="query", resultSet=this.sql.from);
					
				} else {
			
					// set up a datasource
					if (Len(this.datasource) EQ 0)
						throwException("Cannot execute query without a datasource");
					loc.query.setDatasource(this.datasource);
				}
				
				// stack on join parameters
				loc.iEnd = ArrayLen(this.sql.joinParameters);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
					loc.query.addParam(value=this.sql.joinParameters[loc.i]);
				
				// stack on where parameters
				loc.iEnd = ArrayLen(this.sql.whereParameters);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
					loc.query.addParam(value=this.sql.whereParameters[loc.i]);
				
				// stack on having parameters
				loc.iEnd = ArrayLen(this.sql.havingParameters);
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
					loc.query.addParam(value=this.sql.havingParameters[loc.i]);
					
				// execute query
				loc.result = loc.query.execute(sql=this.toSql());
				
				// save objects
				variables.query = loc.result.getResult();
				variables.result = loc.result.getPrefix();
				
				// build pagination data
				// todo: lazy loading?
				if (variables.paged) {
					variables.paginationData = {
						currentPage = (this.sql.offset / this.sql.limit) + 1,
						perPage = this.sql.limit
					};
				}
				
				// change state
				variables.executed = true;
			}
			
			return variables.query;
		</cfscript>
	</cffunction>
	
	<cffunction name="result" returntype="struct" access="public" hint="Return result object generated by query()">
		<cfscript>
			if (variables.executed EQ false OR NOT IsStruct(variables.result))
				this.query();
			return variables.result;
		</cfscript>
	</cffunction>
	
	<cffunction name="pagination" returntype="struct" access="public" hint="Return structure describing pagination state">
		<cfscript>
			if (variables.paged EQ false OR NOT IsStruct(variables.paginationData))
				return false;
			return variables.paginationData;
		</cfscript>
	</cffunction>
	
	<cffunction name="buildModelArray" returntype="array" access="public" hint="Return array of all models involved in query">
		<cfscript>
			var models = [];
			if (StructKeyExists(this.sql, "from") AND typeOf(this.sql.from) EQ "cfrel.nodes.table" AND IsObject(this.sql.from.model))
				ArrayAppend(models, this.sql.from);
			return models;
		</cfscript>
	</cffunction>
	
	<!---------------------
	--- Private Methods ---
	---------------------->
	
	<cffunction name="_appendFieldsToClause" returntype="void" access="private" hint="Take either lists or name/value pairs and append to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="string" required="true" />
		<cfargument name="args" type="struct" required="true" />
		<cfscript>
			var loc = {};
			loc.iEnd = StructCount(arguments.args);
			
			// do not allow empty call
			if (loc.iEnd EQ 0) {
				throwException("Arguments are required in #UCase(arguments.clause)#");
				
			} else {
			
				// loop over all arguments
				for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++) {
					loc.value = _transformInput(arguments.args[loc.i], arguments.clause);
					
					if (IsObject(loc.value)) {
						ArrayAppend(this.sql[arguments.scope], loc.value);
					} else if (IsArray(loc.value)) {
						loc.jEnd = ArrayLen(loc.value);
						for (loc.j = 1; loc.j LTE loc.jEnd; loc.j++)
							ArrayAppend(this.sql[arguments.scope], loc.value[loc.j]);
					} else {
						throwException("Unknown return from parser in #UCase(arguments.clause)#");
					}
				}
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendConditionsToClause" returntype="void" access="private" hint="Take conditions and parameters and append to arrays">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="string" required="true" />
		<cfargument name="parameterScope" type="string" required="true" />
		<cfargument name="args" type="struct" required="true" />
		<cfscript>
			var loc = {};
			
			// get count of arguments
			loc.argumentCount = StructCount(arguments.args);
			
			// if arguments are empty
			if (loc.argumentCount EQ 0) {
				throwException(message="Relation requires arguments for #UCase(arguments.clause)#");
				
			// if a text clause was passed
			} else if (StructKeyExists(arguments.args, "$clause")) {
				
				// make sure clause fragment is a string
				if (NOT IsSimpleValue(arguments.args.$clause) OR Len(arguments.args.$clause) EQ 0)
					throwException(message="#UCase(arguments.clause)# clause must be a string with length > 0");
					
				// count the number of placeholders in clause and argument array
				loc.placeholderCount = Len(arguments.args.$clause) - Len(Replace(arguments.args.$clause, "?", "", "ALL"));
				loc.parameterCount = iif(StructKeyExists(arguments.args, "$params"), "ArrayLen(arguments.args.$params)", DE(0));
				
				// make sure the numbers are equal
				if (loc.placeholderCount NEQ loc.parameterCount)
					throwException(message="Parameter count does not match number of placeholders in #UCase(arguments.clause)# clause");
					
				// append clause and parameters to sql options
				ArrayAppend(this.sql[arguments.scope], _transformInput(arguments.args.$clause, arguments.clause));
				for (loc.i = 1; loc.i LTE loc.parameterCount; loc.i++)
					ArrayAppend(this.sql[arguments.parameterScope], arguments.args.$params[loc.i]);
				
			} else {
				
				// loop over parameters
				for (loc.key in arguments.args) {
					
					// FIXME: (1) railo seems to keep these arguments around
					if (ListFindNoCase("$clause,$params", loc.key))
						continue;
					
					// grab the value from arguments and decide its type
					loc.value = arguments.args[loc.key];
					loc.type = typeOf(loc.value);
					
					// use an IN if value is an array
					if (loc.type EQ "array")
						loc.clause = "#loc.key# IN (?)";
						
					// use an equality check if value is simple
					else if (loc.type EQ "simple")
						loc.clause = "#loc.key# = ?";
						
					// throw an error otherwise
					else
						throwException("Invalid parameter to #UCase(arguments.clause)# clause. Only arrays and simple values may be used.");
					
					// FIXME: (2) note that we found a good value
					loc.success = true;
						
					// append clause and parameters
					ArrayAppend(this.sql[arguments.scope], _transformInput(loc.clause, arguments.clause));
					ArrayAppend(this.sql[arguments.parameterScope], loc.value);
				}
				
				// FIXME: (3) throw an error if a good value was not found
				if (NOT StructKeyExists(loc, "success"))
					throwException(message="Relation requires arguments for #UCase(arguments.clause)#");
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="_transformInput" returntype="any" access="private">
		<cfargument name="obj" type="any" required="true">
		<cfargument name="clause" type="string" default="SELECT">
		<cfscript>
			var loc = {};
			loc.type = typeOf(arguments.obj);
			
			// nodes should pass straight through
			if (REFindNoCase("^cfrel\.nodes\.", loc.type) GT 0)
				return loc.obj;

			// parse simple values with parser
			if (loc.type EQ "simple")
				return variables.parser.parse(arguments.obj, arguments.clause);
				
			// throw error if we havent found it yet
			throwException("Invalid object type passed into #UCase(arguments.clause)#");
		</cfscript>
	</cffunction>
</cfcomponent>