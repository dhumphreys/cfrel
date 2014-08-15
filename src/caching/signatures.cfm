<cffunction name="appendSignature" access="public" hint="Add a new action to the current build signature">
	<cfargument name="func" type="string" required="true" />
	<cfargument name="args" type="struct" required="true" />
	<cfscript>
		// create signature shell
		var signature = {func=arguments.func, args={}};

		// generate signature for each argument
		for (var argKey IN arguments.args)
			signature.args[argKey] = signatureOf(arguments.args[argKey]);

		// append to the current relation's build signature
		ArrayAppend(this.buildSignature, signature, false);

		return this;
	</cfscript>
</cffunction>

<cffunction name="removeFromSignature" returntype="void" access="public" hint="Remove from the current build signature all actions whose functions match keys in a struct">
	<cfargument name="funcStruct" type="struct" required="true" />
	<cfscript>
		// create array for new signature
		var newBuildSignature = CreateObject('java', 'java.util.ArrayList').init();

		// add only the actions whose functions don't match any in funcStruct
		for (var action IN this.buildSignature) {
			if (StructKeyExists(funcStruct, action.func))
				continue;
				
			ArrayAppend(newBuildSignature, action, false);
		}
		
		// replace the current signature with the new one
		this.buildSignature = newBuildSignature;
	</cfscript>
</cffunction>

<cffunction name="signatureOf" returntype="any" access="private" hint="Get a type-dependent signature from an object">
	<cfargument name="obj" type="any" required="true" />
	<cfscript>
		var signature = "{{invalid}}";

		if (IsSimpleValue(arguments.obj))
			signature = arguments.obj;
		else {
			var targetObject = arguments.obj;
			var obj_isQuery = IsQuery(targetObject);
			if (obj_isQuery OR IsArray(targetObject)) {

				// if we can, try to load pre-generated JSON serialization from request cache to save time
				if (request.cfrel.jsonCache.containsKey(targetObject)) {
					signature = request.cfrel.jsonCache.get(targetObject);
				} else {
					// otherwise, serialize the query/array
					var jsonData = SerializeJSON(targetObject);
					request.cfrel.jsonCache.put(targetObject, jsonData);
					signature = jsonData;
				}
			} else {
				var meta = GetMetaData(targetObject);
				
				// if the argument is a component/object, normally return its path
				if (StructKeyExists(meta, "fullname")) {
					signature = meta.fullname;

					if (CompareNoCase(signature, "plugins.cfrel.lib.Relation") EQ 0)
						signature = targetObject.buildSignature;
				} else if (StructKeyExists(targetObject, "$class")) {
					signature = targetObject.$class;
					if (StructKeyExists(targetObject, "subject"))
						signature &= targetObject.subject;
				}
			}
		}

		// Hash long signatures to save space and time
		if (IsSimpleValue(signature) AND Len(signature) > 96)
			signature = getSignatureHash(signature);

		return signature;
	</cfscript>
</cffunction>

<cffunction name="getSignatureHash" returntype="string" access="public">
	<cfargument name="signature" type="string" required="true" />
	<cfscript>
		if (inCache("signatureHash", signature)) {
			var hashedSignature = loadCache("signatureHash", signature);
		} else {
			var hashedSignature = Hash(signature, Application.cfrel.HASH_ALGORITHM);
			saveCache("signatureHash", signature, hashedSignature);
		}

		return hashedSignature;
	</cfscript>
</cffunction>