<!---------------------
--- Node Generation ---
---------------------->

<cffunction name="sqlBinaryOp" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.BinaryOp", arguments)>
</cffunction>

<cffunction name="sqlColumn" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Column", arguments)>
</cffunction>

<cffunction name="sqlExpression" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Expression", arguments)>
</cffunction>

<cffunction name="sqlFunction" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Function", arguments)>
</cffunction>

<cffunction name="sqlLiteral" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Literal", arguments)>
</cffunction>

<cffunction name="sqlOrder" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Order", arguments)>
</cffunction>

<cffunction name="sqlTable" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Table", arguments)>
</cffunction>

<cffunction name="sqlUnaryOp" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.UnaryOp", arguments)>
</cffunction>

<cffunction name="sqlWildcard" returntype="any" access="private">
	<cfreturn constructObject("cfrel.nodes.Wildcard", arguments)>
</cffunction>

<cffunction name="constructObject" returntype="any" access="private">
	<cfargument name="cfc" type="string" required="true" />
	<cfargument name="args" type="struct" required="true" />
	<cfreturn CreateObject("component", arguments.cfc).init(argumentCollection=arguments.args) />
</cffunction>