<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfscript>
			variables.sql = {
				select = [],
				joins = [],
				joinParameters = [],
				wheres = [],
				whereParameters = [],
				groups = [],
				havings = [],
				havingParameters = [],
				orders = []
			};
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="new" returntype="struct" access="public" hint="Create new instance of relation">
		<cfscript>
			return CreateObject("component", "cfrel.relation").init();
		</cfscript>
	</cffunction>
	
	<cffunction name="clone" returntype="struct" access="public" hint="Duplicate the relation object">
		<cfscript>
			return Duplicate(this);
		</cfscript>
	</cffunction>
	
	<cffunction name="select" returntype="struct" access="public" hint="Append to the SELECT clause of the relation">
		<cfscript>
			_appendFieldsToClause("SELECT", sql.select, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="from" returntype="struct" access="public" hint="Specify FROM target of either a table or another relation">
		<cfargument name="target" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// accept other relation objects
			loc.meta = getMetaData(arguments.target);
			if (StructKeyExists(loc.meta, "fullname") AND loc.meta.fullname EQ "cfrel.relation")
				sql.from = arguments.target;
				
			// accept simple values (but not arrays, preferably strings)
			else if (NOT IsArray(arguments.target) AND IsSimpleValue(arguments.target))
				sql.from = arguments.target;
			
			// throw error if other type
			else
				throwException("Only a table name or another relation can be in FROM clause");
				
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
			_appendConditionsToClause("WHERE", sql.wheres, sql.whereParameters, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="group" returntype="struct" access="public" hint="Append to GROUP BY clause of the relation">
		<cfscript>
			_appendFieldsToClause("GROUP BY", sql.groups, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="having" returntype="struct" access="public" hint="Append to HAVING clause of the relation">
		<cfargument name="$clause" type="any" required="false" />
		<cfargument name="$params" type="array" required="false" />
		<cfscript>
			_appendConditionsToClause("HAVING", sql.havings, sql.havingParameters, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="order" returntype="struct" access="public" hint="Append to ORDER BY clause of the relation">
		<cfscript>
			_appendFieldsToClause("ORDER BY", sql.orders, arguments);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="limit" returntype="struct" access="public" hint="Restrict the number of records when querying">
		<cfargument name="value" type="numeric" required="true" />
		<cfscript>
			sql.limit = Int(arguments.value);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="offset" returntype="struct" access="public" hint="Skip some records when querying">
		<cfargument name="value" type="numeric" required="true" />
		<cfscript>
			sql.offset = Int(arguments.value);
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="paginate" returntype="struct" access="public" hint="Calculate LIMIT and OFFSET with page number and per-page constraint">
		<cfargument name="page" type="numeric" required="true" />
		<cfargument name="perPage" type="numeric" required="true" />
		<cfscript>
			
			// throw error if bad values are passed
			if (arguments.page LT 1 OR arguments.perPage LT 1)
				throwException("Page and per-page must be greater than zero", "Expression");
			
			// calculate limit and offset
			sql.limit = Int(arguments.perPage);
			sql.offset = (Int(arguments.page) - 1) * sql.limit;
			return this;
		</cfscript>
	</cffunction>
	
	<cffunction name="toSql" returntype="string" access="public" hint="Convert relational data into a SQL string">
	</cffunction>
	
	<!---------------------
	--- Private Methods ---
	---------------------->
	
	<cffunction name="_appendFieldsToClause" returntype="void" access="private" hint="Take either lists or name/value pairs and append to an array">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="array" required="true" />
		<cfargument name="args" type="struct" required="true" />
		<cfscript>
			var loc = {};
			switch (StructCount(arguments.args)) {
				
				// do not allow empty call
				case 0:
					throwException("Arguments are required in #UCase(arguments.clause)#", "Expression");
					break;
					
				// treat single arguments as a list and append each list item
				case 1:
					loc.arguments = ListToArray(arguments.args[1]);
					loc.iEnd = ArrayLen(loc.arguments);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						ArrayAppend(arguments.scope, loc.arguments[loc.i]);
					break;
				
				// loop and append if many arguments are passed
				default:
					for (loc.key in args)
						ArrayAppend(arguments.scope, arguments.args[loc.key]);
					break;
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="_appendConditionsToClause" returntype="void" access="private" hint="Take conditions and parameters and append to arrays">
		<cfargument name="clause" type="string" required="true" />
		<cfargument name="scope" type="array" required="true" />
		<cfargument name="parameterScope" type="array" required="true" />
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
				ArrayAppend(arguments.scope, arguments.args.$clause);
				for (loc.i = 1; loc.i LTE loc.parameterCount; loc.i++)
					ArrayAppend(arguments.parameterScope, arguments.args.$params[loc.i]);
				
			} else {
				
				// loop over parameters
				for (loc.key in arguments.args) {
					
					// FIXME: (1) railo seems to keep these arguments around
					if (ListFindNoCase("$clause,$params", loc.key))
						continue;
					
					// grab the value from arguments
					loc.value = arguments.args[loc.key];
					
					// use an IN if value is an array
					if (IsArray(loc.value))
						loc.clause = "#loc.key# IN ?";
						
					// use an equality check if value is simple
					else if (IsSimpleValue(loc.value))
						loc.clause = "#loc.key# = ?";
						
					// throw an error otherwise
					else
						throwException("Invalid parameter to #UCase(arguments.clause)# clause. Only arrays and simple values may be used.");
					
					// FIXME: (2) note that we found a good value
					loc.success = true;
						
					// append clause and parameters
					ArrayAppend(arguments.scope, loc.clause);
					ArrayAppend(arguments.parameterScope, loc.value);
				}
				
				// FIXME: (3) throw an error if a good value was not found
				if (NOT StructKeyExists(loc, "success"))
					throwException(message="Relation requires arguments for #UCase(arguments.clause)#");
			}
		</cfscript>
	</cffunction>
</cfcomponent>