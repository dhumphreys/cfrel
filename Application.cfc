<cfcomponent output="false">
	<cffunction name="onRequestStart">
		<cfscript>
			application.cfrel = {};
			application.cfrel.cfcPrefix = "src";
		</cfscript>
	</cffunction>
</cfcomponent>