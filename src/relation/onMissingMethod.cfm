<cffunction name="onMissingMethod" returntype="any" access="public">
	<cfargument name="missingMethodName" type="string" required="true" />
	<cfargument name="missingMethodArguments" type="struct" required="true" />
	<cfscript>
		var loc = {};
		if (IsObject(this.model)) {
			
			// look for possible named scopes
			loc.scopes = this.mapper.scopes(this.model);
			if (StructKeyExists(loc.scopes, arguments.missingMethodName)) {
				var $scope = loc.scopes[arguments.missingMethodName];
				if (IsCustomFunction($scope))
					$scope(argumentCollection=arguments.missingMethodArguments);
				else if (IsSimpleValue($scope))
					Evaluate($scope);
				return this;
			}
		}
		throwException("Method `#arguments.missingMethodName#` was not found in relation.");
	</cfscript>
</cffunction>
