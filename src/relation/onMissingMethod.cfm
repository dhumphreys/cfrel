<cffunction name="onMissingMethod" returntype="any" access="public">
	<cfargument name="missingMethodName" type="string" required="true" />
	<cfargument name="missingMethodArguments" type="struct" required="true" />
	<cfscript>
		var loc = {};
		if (this.model NEQ false) {
			
			// look for possible named scopes
			loc.scopes = mapper().scopes(this.model);
			if (StructKeyExists(loc.scopes, arguments.missingMethodName)) {
				var $scope = loc.scopes[arguments.missingMethodName];
				if (IsCustomFunction($scope))
					loc.returnValue = $scope(argumentCollection=arguments.missingMethodArguments);
				else if (IsSimpleValue($scope))
					loc.returnValue = Evaluate($scope);
				if (StructKeyExists(loc, "returnValue") AND IsObject(loc.returnValue))
					return loc.returnValue;
				return this;
			}
		}
		throwException("Method `#arguments.missingMethodName#` was not found in relation.");
	</cfscript>
</cffunction>
