<cffunction name="init" returntype="struct" access="public" hint="Constructor">
	<cfargument name="datasource" type="string" default="" />
	<cfargument name="visitor" type="string" default="Sql" />
	<cfargument name="qoq" type="boolean" default="false" />
	<cfargument name="model" type="any" default="false" />
	<cfargument name="parameterize" type="boolean" default="false" />
	<cfargument name="cacheParse" type="boolean" default="false" />
	<cfargument name="cacheMap" type="boolean" default="false" />
	<cfargument name="cacheSql" type="boolean" default="false" />
	<cfargument name="includeSoftDeletes" type="boolean" default="false" />
	<cfscript>
		
		// datasource and adapter settings
		variables.visitorClass = arguments.visitor;
		variables.includeSoftDeletes = arguments.includeSoftDeletes;
		this.datasource = arguments.datasource;
		
		// store model that this relation deals with
		this.model = arguments.model;
		
		// struct to hold SQL tree
		this.sql = {
			select = [],
			selectFlags = [],
			froms = [],
			joins = [],
			wheres = [],
			groups = [],
			havings = [],
			orders = []
		};

		// struct to hold SQL parameters
		this.params = {
			joins = [],
			wheres = [],
			havings = []
		};
		
		// set up max rows for cfquery tag
		this.maxRows = 0;
		
		// internal control and value variables
		variables.cache = {};
		variables.currentRow = 0;
		variables.executed = false;
		variables.qoq = arguments.qoq;
		variables.paged = false;
		variables.paginationData = false;

		// global caching settings
		setupCaching(argumentCollection=arguments);

		// cache initialization options
		if (variables.cacheSql)
			appendSignature(GetFunctionCalledName(), {datasource=arguments.datasource, parameterize=arguments.parameterize, includeSoftDeletes=arguments.includeSoftDeletes});
		
		/***************
		* MAPPING VARS *
		***************/

		variables.map = false;
		
		/***************
		* PARSING VARS *
		***************/
		
		// store parameterization preference
		variables.parameterize = arguments.parameterize;
		
		// token and literal storage
		variables.tokens = [];
		variables.literals = [];
		
		// token index during parse
		variables.tokenIndex = 1;
		variables.tokenLen = 0;
		
		// temporary hold column name that positional parameters may refer to
		variables.tmpParamColumn = "";
		
		return this;
	</cfscript>
</cffunction>

<cffunction name="setupCaching" returntype="void" access="public">
	<cfscript>
		// Application-level cache override
		variables.allowCaching = StructKeyExists(Application.cfrel, "allowCaching") ? Application.cfrel.allowCaching : true;

		// default caching to false
		variables.cacheParse = variables.cacheMap = variables.cacheSql = false;

		// setup caching structures if caching is allowed
		if (variables.allowCaching) {

			variables.cacheParse = arguments.cacheParse;
			variables.cacheMap = arguments.cacheMap;
			variables.cacheSql = arguments.cacheSql;

			if (NOT StructKeyExists(request, "cfrel"))
				request.cfrel = {};

			if (NOT StructKeyExists(request.cfrel, "startTime"))
				request.cfrel.startTime = Now();

			if (variables.cacheSql) {
				this.buildSignature = CreateObject("java", "java.util.ArrayList").init();

				if (NOT StructKeyExists(request.cfrel, "jsonCache"))
					request.cfrel.jsonCache = {};
			}
		}
	</cfscript>
</cffunction>

<cffunction name="new" returntype="struct" access="public" hint="Create new instance of relation">
	<cfreturn relation(argumentCollection=arguments) />
</cffunction>

<cffunction name="clone" returntype="struct" access="public" hint="Duplicate the relation object">
	<cfscript>
		var loc = {};
		
		// duplicate object and sql
		loc.rel = Duplicate(this);
		loc.rel.executed = false;
		
		// remove query values that should not be kept in new instance
		if (variables.executed EQ true OR StructKeyExists(variables.cache, "query")) {
			loc.private = injectInspector(loc.rel)._inspect();
			loc.private.cache = {};
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

<cffunction name="subQuery" returntype="any" access="public" hint="Create new rel with the current rel as the child">
	<cfreturn new(datasource=this.datasource, visitor=variables.visitorClass, qoq=variables.qoq, parameterize=variables.parameterize, cacheParse=variables.cacheParse, cacheMap=variables.cacheMap, cacheSql=variables.cacheSql).from(this) />
</cffunction>

<cffunction name="qoq" returntype="struct" access="public" hint="Return a QoQ relation with the current recordset as the FROM">
	<cfreturn this.new(model=this.model, parameterize=variables.parameterize, cacheParse=variables.cacheParse, cacheMap=variables.cacheMap, cacheSql=variables.cacheSql).from(this.query()) />
</cffunction>
