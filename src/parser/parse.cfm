<cffunction name="parse" returntype="any" access="public" hint="Turn a SQL string into a tree of nodes">
	<cfargument name="str" type="string" required="true" />
	<cfargument name="clause" type="string" default="WHERE" />
	<cfargument name="params" type="array" default="#ArrayNew(1)#" />
	<cfscript>
		var loc = {};
		
		// try to read from cache if turned on
		if (variables.cacheParse) {
		
			// create key for cache
			loc.cacheKey = Hash("#arguments.clause#:#arguments.str#", "MD5");
			
			// set up parse cache
			if (NOT StructKeyExists(application, "cfrel"))
				application.cfrel = {parseCache={}, paramCache={}};
				
			// if key exists, set the parameter columns
			if (StructKeyExists(application.cfrel.paramCache, loc.cacheKey))
				variables.parameterColumns = application.cfrel.paramCache[loc.cacheKey];
				
			// if key exists, just return cached parse tree
			if (StructKeyExists(application.cfrel.parseCache, loc.cacheKey))
				return Duplicate(application.cfrel.parseCache[loc.cacheKey]);
		}
		
		// break incoming string into tokens
		tokenize(arguments.str);
		
		// set positional parameters in variables scope
		variables.parseParameters = arguments.params;
		
		// parse string depending on clause type
		switch (arguments.clause) {
			case "SELECT":
			case "GROUP BY":
				loc.tree = exprs();
				break;
			case "ORDER BY":
				loc.tree = orderExprs();
				break;
			default:
				loc.tree = expr();
		}
		
		// if tokens or parameters are still left, throw an error
		if (tokenIndex LTE tokenLen)
			throwException("Parsing error. Not all tokens processed. #tokenIndex - 1# of #tokenLen# processed.");
		if (ArrayLen(variables.parseParameters))
			throwException("Parsing error. Too many parameters passed into #UCase(arguments.clause)#.");
			
		// cache the parse tree and parameter columns in the application scope
		if (variables.cacheParse) {
			application.cfrel.parseCache[loc.cacheKey] = Duplicate(loc.tree);
			application.cfrel.paramCache[loc.cacheKey] = variables.parameterColumns;
		}
		
		return loc.tree;
	</cfscript>
</cffunction>

<cffunction name="tokenize" returntype="void" access="private" hint="Turn a SQL string into an array of terminals">
	<cfargument name="str" type="string" required="true" />
	<cfscript>
		var loc = {};

		// extract literals (strings, numbers, dates, etc) out of the input string
		variables.literals = REMatch(literalRegex, arguments.str);
		
		// replace literals with placeholders
		arguments.str = REReplaceNoCase(arguments.str, l.date, t.date, "ALL");
		arguments.str = REReplaceNoCase(arguments.str, l.string, t.string, "ALL");
		arguments.str = REReplaceNoCase(arguments.str, l.decimal, t.decimal, "ALL");
		arguments.str = REReplaceNoCase(arguments.str, l.integer, t.integer, "ALL");
		
		// replace escaped identifiers with their unescaped values
		arguments.str = REReplace(arguments.str, t.identifier, "\1", "ALL");
		
		// split string into tokens using using terminal pattern
		variables.tokens = REMatchNoCase(terminalRegex, arguments.str);
		
		// set up counters for rest of parse
		variables.tokenIndex = 1;
		variables.tokenLen = ArrayLen(variables.tokens);
	</cfscript>
</cffunction>

<cffunction name="peek" returntype="boolean" access="private" hint="See if next item on token stack matches regex">
	<cfargument name="regex" type="string" required="true" />
	<cfargument name="offset" type="numeric" default="0" />
	<cfscript>
		if (tokenIndex + arguments.offset GT tokenLen)
			return false;
		return (REFindNoCase("^(?:#arguments.regex#)$", tokens[tokenIndex + arguments.offset]) GT 0);
	</cfscript>
</cffunction>

<cffunction name="accept" returntype="boolean" access="private" hint="Return true if next item on stack matches and increment pointer">
	<cfargument name="regex" type="string" required="true" />
	<cfscript>
		if (peek(arguments.regex)) {
			tokenIndex++;
			return true;
		}
		return false;
	</cfscript>
</cffunction>

<cffunction name="expect" returntype="boolean" access="private" hint="Accept next item on stack or error out">
	<cfargument name="regex" type="string" required="true" />
	<cfscript>
		if (accept(arguments.regex))
			return true;
		throwException("Unexpected token found in SQL parse: #tokens[tokenIndex]#");
		return false;
	</cfscript>
</cffunction>

<cffunction name="popLiteral" returntype="any" access="private" hint="Pop the next literal string or number of the literals stack">
	<cfscript>
		var loc = {};
		if (ArrayLen(literals) GT 0) {
			loc.val = literals[1];
			ArrayDeleteAt(literals, 1);
			return loc.val;
		}
		throwException("No more literals found in parse");
	</cfscript>
</cffunction>
