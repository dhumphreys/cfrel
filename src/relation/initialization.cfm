<cffunction name="init" returntype="struct" access="public" hint="Constructor">
	<cfargument name="datasource" type="string" default="" />
	<cfargument name="visitor" type="string" default="Sql" />
	<cfargument name="mapper" type="string" default="Mapper" />
	<cfargument name="qoq" type="boolean" default="false" />
	<cfargument name="model" type="any" default="false" />
	<cfargument name="cache" type="string" default="" />
	<cfargument name="cacheParse" type="boolean" default="#ListFindNoCase(arguments.cache, 'parse')#" />
	<cfargument name="includeSoftDeletes" type="boolean" default="false" />
	<cfscript>
		
		// store classes used for mapper and visitor
		variables.mapperClass = arguments.mapper;
		variables.visitorClass = arguments.visitor;
		
		// datasource and visitor to use
		this.datasource = arguments.datasource;
		this.visitor = CreateObject("component", addCfcPrefix("cfrel.visitors.#arguments.visitor#")).init();
		this.mapper = CreateObject("component", addCfcPrefix("cfrel.mappers.#arguments.mapper#")).init(arguments.includeSoftDeletes);
		
		// store model that this relation deals with
		this.model = arguments.model;
		
		// internal parser
		variables.parser = CreateObject("component", addCfcPrefix("cfrel.Parser")).init(cache=arguments.cacheParse);
		
		// struct to hold SQL tree
		this.sql = {
			select = [],
			selectFlags = [],
			froms = [],
			joins = [],
			joinParameters = [],
			joinParameterColumns = [],
			wheres = [],
			whereParameters = [],
			whereParameterColumns = [],
			groups = [],
			havings = [],
			havingParameters = [],
			havingParameterColumns = [],
			orders = []
		};
		
		// set up max rows for cfquery tag
		this.maxRows = 0;
		
		// internal control and value variables
		variables.cache = {};
		variables.currentRow = 0;
		variables.executed = false;
		variables.mapped = false;
		variables.qoq = arguments.qoq;
		variables.paged = false;
		variables.paginationData = false;
		variables.includeSoftDeletes = arguments.includeSoftDeletes;
		
		return this;
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
		
		// fix for railo as it seems to keep references in the this.sql struct after a duplicate
		if (StructKeyExists(server, "railo"))
			loc.rel.sql = Duplicate(this.sql);
		
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
	<cfreturn new(datasource=this.datasource, visitor=variables.visitorClass, qoq=variables.qoq).from(this) />
</cffunction>
