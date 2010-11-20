<cfcomponent output="false">
	<cffunction name="init" returntype="void" access="private">
		<cfscript>
			var loc = {};
			for (loc.key in arguments)
				this[loc.key] = arguments[loc.key];
		</cfscript>
	</cffunction>
</cfcomponent>