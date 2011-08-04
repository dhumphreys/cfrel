<!---------------------
--- Private Methods ---
---------------------->
	
<cffunction name="injectInspector" returntype="any" access="private" hint="Make any object inspectable">
	<cfargument name="obj" type="any" required="true" />
	<cfscript>
		if (NOT StructKeyExists(arguments.obj, "_inspect"))
			arguments.obj._inspect = variables._inspect;
		return arguments.obj;
	</cfscript>
</cffunction>

<!---------------------------
--- Methods For Injection ---
---------------------------->

<cffunction name="_inspect" returntype="struct" access="private" hint="Method to return objects variables scope">
	<cfreturn variables />
</cffunction>