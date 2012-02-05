<cfcomponent extends="Mapper" displayName="CFWheels" output="false">
	
	<cffunction name="aliasName" returntype="string" access="public" hint="Return alias name to reference in query">
		<cfargument name="model" type="any" required="true" />
		<cfreturn arguments.model.$classData().modelName />
	</cffunction>
	
	<cffunction name="tableName" returntype="string" access="public" hint="Return table name to reference in query">
		<cfargument name="model" type="any" required="true" />
		<cfreturn arguments.model.$classData().tableName />
	</cffunction>
	
	<cffunction name="primaryKey" returntype="string" access="public" hint="Get primary key list from model">
		<cfargument name="model" type="any" required="true" />
		<cfreturn arguments.model.primaryKey() />
	</cffunction>
	
	<cffunction name="properties" returntype="struct" access="public" hint="Return all database properties in a structure">
		<cfargument name="model" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.returnValue = StructNew();
			
			// loop over database properties
			loc.properties = arguments.model.$classData().properties;
			for (loc.key in loc.properties) {
				loc.col = loc.properties[loc.key];
				
				// create new column entry with specified
				loc.newCol = StructNew();
				loc.newCol.property = loc.key;
				loc.newCol.column = loc.col.column;
				loc.newCol.cfsqltype = loc.col.type;
				
				// append column to return list
				loc.returnValue[loc.key] = loc.newCol;
			}
			
			return loc.returnValue;
		</cfscript>
	</cffunction>
	
	<cffunction name="calculatedProperties" returntype="struct" access="public" hint="Return all calculated properties in a structure">
		<cfargument name="model" type="any" required="true" />
		<cfscript>
			var loc = {};
			loc.returnValue = StructNew();
			
			// loop over calculated properties
			loc.properties = arguments.model.$classData().calculatedProperties;
			for (loc.key in loc.properties) {
				loc.col = loc.properties[loc.key];
				
				// create new column entry with specified
				loc.newCol = StructNew();
				loc.newCol.property = loc.key;
				loc.newCol.sql = loc.col.sql;
				
				// append column to return list
				loc.returnValue[loc.key] = loc.newCol;
			}
			
			return loc.returnValue;
		</cfscript>
	</cffunction>
	
	<cffunction name="association" returntype="struct" access="public" hint="Return specific association details">
		<cfargument name="model" returntype="any" required="true" />
		<cfargument name="association" type="string" required="true" />
		<cfscript>
			var loc = {};
			
			// look up associations
			loc.associations = injectInspector(arguments.model)._inspect().wheels.class.associations;
			
			// throw an error if association is not found
			if (NOT StructKeyExists(loc.associations, arguments.association))
				super.association(argumentCollection=arguments);
				
			// get association and preload joined model class
			loc.association = loc.associations[arguments.association];
			loc.association.model = arguments.model.model(loc.association.modelName);
			
			return loc.association;
		</cfscript>
	</cffunction>
	
	<cffunction name="buildStructCache" returntype="array" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfargument name="deep" type="boolean" default="false" />
		<cfargument name="flat" type="boolean" default="#NOT arguments.deep#" />
		<cfscript>
			if (IsObject(arguments.model) AND NOT arguments.flat)
				return arguments.model.$serializeQueryToStructs(arguments.query, includeString(), false, arguments.deep);
			return super.buildStructCache(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="buildObjectCache" returntype="array" access="public">
		<cfargument name="query" type="query" required="true" />
		<cfargument name="model" type="any" default="false" />
		<cfargument name="deep" type="boolean" default="true" />
		<cfargument name="flat" type="boolean" default="false" />
		<cfscript>
			var loc = {};
			if (IsObject(arguments.model)) {
				loc.array = arguments.model.$serializeQueryToObjects(arguments.query, includeString(), false, arguments.deep AND NOT arguments.flat);
				if (arguments.flat) {
					loc.iEnd = ArrayLen(loc.array);
					for (loc.i = 1; loc.i LTE loc.iEnd; loc.i++)
						loc.array[loc.i].setProperties(super.buildStruct(arguments.query, loc.i, arguments.model));
				}
				return loc.array;
			}
			return super.buildObjectCache(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="scopes" returntype="any" access="public">
		<cfargument name="model" type="any" required="true" />
		<cfreturn arguments.model.scopes() />
	</cffunction>
	
	<cffunction name="beforeFind" returntype="void" access="public" hint="Do before-find relation logic">
		<cfargument name="relation" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// if recordset is paged, set up ordering like cfwheels
			// TODO: we are not making sure that all primary key fields are in the order clause here
			if (arguments.relation.isPaged() AND IsObject(arguments.relation.model) AND ArrayLen(arguments.relation.sql.orders) EQ 0) {
				
				// add the primary keys to the order list
				arguments.relation.order(arguments.relation.model.primaryKey());
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="afterFind" returntype="query" access="public" hint="Do after-find query processing">
		<cfargument name="model" type="any" required="true" />
		<cfargument name="query" type="query" required="true" />
		<cfscript>
			arguments.model.$callback("afterFind", true, arguments.query);
			return arguments.query;
		</cfscript>
	</cffunction>
	
</cfcomponent>