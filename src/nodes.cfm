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
	<cfargument name="table" type="any" default="" />
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

<cffunction name="sqlOrder" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfargument name="descending" type="boolean" default="false" />
	<cfreturn constructObject("cfrel.nodes.Order", arguments)>
</cffunction>

<cffunction name="sqlParen" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.Paren", arguments)>
</cffunction>

<cffunction name="sqlSubQuery" returntype="any" access="private">
	<cfargument name="subject" type="any" required="true" />
	<cfreturn constructObject("cfrel.nodes.SubQuery", arguments)>
</cffunction>

<cffunction name="sqlTable" returntype="any" access="private">
	<cfargument name="table" type="string" default="" />
	<cfargument name="alias" type="string" default="" />
	<cfargument name="model" type="any" default="false" />
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
		for (loc.key in arguments.args)
			loc.obj[loc.key] = arguments.args[loc.key];
		return loc.obj;
	</cfscript>
</cffunction>