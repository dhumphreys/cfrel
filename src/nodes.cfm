<!------------------------
--- Mapping Structures ---
------------------------->

<cffunction name="emptyMap" returntype="struct" access="public" hint="Generate an empty mapping structure">
	<cfscript>
		var map = StructNew();
		map.tables = StructNew();
		map.aliases = StructNew();
		map.columns = StructNew();
		map.includes = StructNew();
	</cfscript>
	<cfreturn map />
</cffunction>

<!---------------------
--- Node Generation ---
---------------------->

<cffunction name="sqlAlias" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfargument name="alias" type="string" default="" />
	<cfreturn constructObject("cfrel.nodes.Alias", arguments)>
</cffunction>

<cffunction name="sqlBetween" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfargument name="start" type="any" required="true" />
	<cfargument name="end" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.Between", arguments)>
</cffunction>

<cffunction name="sqlBinaryOp" returntype="any" access="private">
	<cfargument name="left" type="any" required="true" />
	<cfargument name="op" type="string" required="true" />
	<cfargument name="right" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.BinaryOp", arguments)>
</cffunction>

<cffunction name="sqlCase" returntype="any" access="private">
	<cfargument name="subject" type="any" default="" />
	<cfargument name="cases" type="any" required="true" />
	<cfargument name="els" type="any" default="" />
	<cfreturn constructObject("cfrel.nodes.Case", arguments)>
</cffunction>

<cffunction name="sqlCaseCondition" returntype="any" access="private">
	<cfargument name="condition" type="any" default="" />
	<cfargument name="subject" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.CaseCondition", arguments)>
</cffunction>

<cffunction name="sqlCast" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfargument name="type" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.Cast", arguments)>
</cffunction>

<cffunction name="sqlColumn" returntype="any" access="private">
	<cfargument name="column" type="string" required="true" />
	<cfargument name="alias" type="string" default="" />
	<cfreturn constructObject("cfrel.nodes.Column", arguments)>
</cffunction>

<cffunction name="sqlFunction" returntype="any" access="private">
	<cfargument name="name" type="string" required="true" />
	<cfargument name="scope" type="any" default="" />
	<cfargument name="args" type="array" default="#[]#" />
	<cfargument name="distinct" type="boolean" default="false" />
	<cfreturn constructObject("cfrel.nodes.Function", arguments)>
</cffunction>

<cffunction name="sqlInclude" returntype="any" access="private">
	<cfargument name="include" type="string" required="true" />
	<cfargument name="tree" type="struct" required="true" />
	<cfargument name="includeKey" type="string" default="#arguments.include#" />
	<cfargument name="includeSoftDeletes" type="boolean" required="false" />
	<cfreturn constructObject("cfrel.nodes.Include", arguments)>
</cffunction>

<cffunction name="sqlJoin" returntype="any" access="private">
	<cfargument name="table" type="any" required="true" />
	<cfargument name="condition" type="any" default="false" />
	<cfargument name="type" type="string" default="inner" />
	<cfreturn constructObject("cfrel.nodes.Join", arguments)>
</cffunction>

<cffunction name="sqlLiteral" returntype="any" access="private">
	<cfargument name="subject" type="string" required="true" />
	<cfreturn constructObject("cfrel.nodes.Literal", arguments)>
</cffunction>

<cffunction name="sqlModel" returntype="any" access="private">
	<cfargument name="model" type="string" required="true" />
	<cfargument name="alias" type="string" default="" />
	<cfargument name="includeSoftDeletes" type="boolean" required="false" />
	<cfreturn constructObject("cfrel.nodes.Model", arguments)>
</cffunction>

<cffunction name="sqlOrder" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfargument name="descending" type="boolean" default="false" />
	<cfreturn constructObject("cfrel.nodes.Order", arguments)>
</cffunction>

<cffunction name="sqlParam" returntype="any" access="private">
	<cfargument name="value" type="any" required="false" />
	<cfargument name="null" type="boolean" default="false" />
	<cfargument name="cfsqltype" type="string" required="false" />
	<cfargument name="column" type="string" required="false" />
	<cfreturn constructObject("cfrel.nodes.Param", arguments)>
</cffunction>

<cffunction name="sqlParen" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.Paren", arguments)>
</cffunction>

<cffunction name="sqlQuery" returntype="any" access="private">
	<cfargument name="subject" type="query" required="true" />
	<cfargument name="alias" type="string" default="" />
	<cfreturn constructObject("cfrel.nodes.Query", arguments)>
</cffunction>

<cffunction name="sqlSubQuery" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfargument name="alias" type="string" default="" />
	<cfreturn constructObject("cfrel.nodes.SubQuery", arguments)>
</cffunction>

<cffunction name="sqlTable" returntype="any" access="private">
	<cfargument name="table" type="string" default="" />
	<cfargument name="alias" type="string" default="" />
	<cfreturn constructObject("cfrel.nodes.Table", arguments)>
</cffunction>

<cffunction name="sqlType" returntype="any" access="private">
	<cfargument name="name" type="any" required="true" />
	<cfargument name="val1" type="string" default="" />
	<cfargument name="val2" type="string" default="" />
	<cfreturn constructObject("cfrel.nodes.Type", arguments)>
</cffunction>

<cffunction name="sqlUnaryOp" returntype="any" access="private">
	<cfargument name="op" type="string" required="true" />
	<cfargument name="subject" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.UnaryOp", arguments)>
</cffunction>

<cffunction name="sqlWildcard" returntype="any" access="private">
	<cfargument name="subject" type="any" default="" />
	<cfreturn constructObject("cfrel.nodes.Wildcard", arguments)>
</cffunction>

<cffunction name="constructObject" returntype="any" access="private">
	<cfargument name="class" type="string" required="true" />
	<cfargument name="args" type="struct" required="true" />
	<cfscript>
		var loc = {};
		loc.obj = {$class=arguments.class};
		StructAppend(loc.obj, arguments.args);
		return loc.obj;
	</cfscript>
</cffunction>