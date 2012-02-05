<cffunction name="init" returntype="struct" access="public" hint="Constructor">
	<cfargument name="datasource" type="string" default="" />
	<cfargument name="visitor" type="string" default="Sql" />
	<cfargument name="qoq" type="boolean" default="false" />
	<cfargument name="model" type="any" default="false" />
	<cfargument name="parameterize" type="boolean" default="false" />
	<cfargument name="cache" type="string" default="" />
	<cfargument name="cacheParse" type="boolean" default="#ListFindNoCase(arguments.cache, 'parse')#" />
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
		
		/***************
		* MAPPING VARS *
		***************/
		
		variables.mappings = {};
		variables.mappings.columns = {};
		variables.mappings.includes = javaHash();
		variables.mappings.tableAlias = {};
		variables.mappings.tableColumns = {};
		variables.mappings.queue = [];
		variables.mappings.wildcards = {};
		
		/***************
		* PARSING VARS *
		***************/
		
		// store parameterization preference
		variables.parameterize = arguments.parameterize;
		
		// set cache setting (if application scope is defined)
		variables.cacheParse = arguments.cacheParse AND IsDefined("application");
		
		// string and numeric literals
		variables.l = {date="'{ts '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'}'", string="'([^']*((\\|')'[^']*)*[^\'])?'", integer="\b\d+\b", decimal="-?(\B|\b\d+)\.\d+\b"};
		
		// build regex to match literals
		variables.literalRegex = "(#l.date#|#l.string#|#l.decimal#|#l.integer#)";
		
		// terminals (and literal placeholders)
		variables.t = {date="::dt::", string="::str::", decimal="::dec::", integer="::int::", param="\?", dot="\.",
			comma=",", lparen="\(", rparen="\)", addOp="\+|-|&|\^|\|", star="\*", mulOp="\*|/|%", as="\bAS\b",
			unaryOp="\+|-|~|\bNOT\b", compOp="<=>|<=|>=|<>|!=|!>|!<|=|<|>|\bLIKE\b", between="\bBETWEEN\b",
			andOp="\bAND\b", orOp="\bOR\b", neg="\bNOT\b", sortOp="\bASC\b|\bDESC\b", null="\bNULL\b",
			cast="\bCAST\b", iss="\bIS\b", inn="\bIN\b", identifier="[\[""`]?(\w+)[""`\]]?", kase="\bCASE\b", when="\bWHEN\b",
			then="\bTHEN\b", els="\bELSE\b", end="\bEND\b", like="\bLIKE\b", distinct="\bDISTINCT\b"};
		
		// build regex to match any of the terminals above
		variables.terminalRegex = "";
		for (loc.key in variables.t)
			terminalRegex = ListAppend(terminalRegex, t[loc.key], "|");
				
		// token and literal storage
		variables.tokens = [];
		variables.tokenTypes = [];
		variables.literals = [];
		
		// store parameter values that are passed in
		variables.parseParameters = [];
		
		// token index during parse
		variables.tokenIndex = 1;
		variables.tokenLen = 0;
		
		// temporary hold column name that positional parameters may refer to
		variables.tmpParamColumn = "";
		
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
	<cfreturn new(datasource=this.datasource, visitor=variables.visitorClass, qoq=variables.qoq, parameterize=variables.parameterize).from(this) />
</cffunction>

<cffunction name="qoq" returntype="struct" access="public" hint="Return a QoQ relation with the current recordset as the FROM">
	<cfreturn this.new(model=this.model).from(this.query()) />
</cffunction>
