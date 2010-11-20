<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfargument name="datasource" type="string" default="" />
		<cfargument name="visitor" type="string" default="Sql" />
		<cfscript>
			
			// datasource and visitor to use
			this.datasource = arguments.datasource;
			this.visitor = CreateObject("component", "cfrel.visitors.#arguments.visitor#");
			
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
			variables.qoq = false;
			
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="new" returntype="struct" access="public" hint="Create new instance of relation">
		<cfscript>
			return CreateObject("component", "cfrel.Relation").init();
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
			switch(typeOf(arguments.target)) {
				
				// accept relations and strings
				case "cfrel.Relation":
				case "simple":
					this.sql.from = arguments.target;
					break;
				
				// accept queries for QoQ operations
				case "query":
					this.sql.from = arguments.target;
					variables.qoq = true;
					break;
					
				// and reject all others by throwing an errors
				default:
					throwException("Only a table name or another relation can be in FROM clause");
			}	
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="include" returntype="struct" access="public" hint="Add a JOIN to the relation using predefined relationships">
		<cfscript>
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="join" returntype="struct" access="public" hint="Add a JOIN to the relation">
		<cfscript>
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
			
			// throw error if bad values are passed
			if (arguments.page LT 1 OR arguments.perPage LT 1)
				throwException("Page and per-page must be greater than zero");
			
			// calculate limit and offset
			this.sql.limit = Int(arguments.perPage);
			this.sql.offset = (Int(arguments.page) - 1) * this.sql.limit;
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="toSql" returntype="string" access="public" hint="Convert relational data into a SQL string">
		<cfscript>
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
	
	<!---------------------
	--- Private Methods ---
	---------------------->
	
	<cffunction name="_appendFieldsToClause" returntype="void" access="private" hint="Take either lists or name/value pairs and append to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="string" required="true" />
		<cfargument name="args" type="struct" required="true" />
		<cfscript>
			var loc = {};
			switch (StructCount(arguments.args)) {
				
				// do not allow empty call
				case 0:
					throwException("Arguments are required in #UCase(arguments.clause)#");
					break;
					
				// treat single arguments as a list and append each list item
				case 1:
					loc.arguments = ListToArray(arguments.args[1]);
					loc.iEnd = ArrayLen(loc.arguments);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						ArrayAppend(this.sql[arguments.scope], _transformInput(loc.arguments[loc.i], arguments.clause));
					break;
				
				// loop and append if many arguments are passed
				default:
					loc.iEnd = StructCount(arguments.args);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						ArrayAppend(this.sql[arguments.scope], _transformInput(arguments.args[loc.i], arguments.clause));
					break;
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
						loc.clause = "#loc.key# IN ?";
						
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
			
			// literals pass straight through
			if (loc.type EQ "cfrel.nodes.literal")
				return arguments.obj;
			
			// determine behavior
			switch(arguments.clause) {
				
				// try to see item as a column or expression
				case "SELECT":
				case "GROUP BY":
					loc.behavior = "select";
					break;
				
				// try to see item as a condition
				case "WHERE":
				case "HAVING":
					loc.behavior = "where";
					break;
				
				// try to see item as a column or expression with order
				case "ORDER BY":
					loc.behavior = "order";
					break;
				
				// have no extra behavior
				default:
					loc.behavior = false;
			}
			
			// if we are dealing with a simple value
			if (loc.type EQ "simple") {
				loc.value = Trim(arguments.obj);
				switch (loc.behavior) {
					case "select": loc.value = loc.value; break;
					case "where": loc.value = loc.value; break;
					case "order": loc.value = loc.value; break;
					default: loc.value = loc.value;
				}
				return loc.value;
			}
			
			// just keep returning other node objects
			if (REFindNoCase("^cfrel\.nodes\.", loc.type) GT 0)
				return loc.obj;
				
			// return relations as expressions with aliases
			if (loc.type EQ "cfrel.relation")
				return expression(loc.obj, "A1");
				
			// throw error if we havent found it yet
			throwException("Invalid object type passed into #UCase(arguments.clause)#");
		</cfscript>
	</cffunction>
</cfcomponent>