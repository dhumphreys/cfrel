<cffunction name="parse" returntype="any" access="public" hint="Turn a SQL string into a tree of nodes">
	<cfargument name="str" type="string" required="true" />
	<cfargument name="clause" type="string" default="WHERE" />
	<cfscript>
		var loc = {};
		
		// determine beginning grammar rule
		switch (arguments.clause) {
			case "SELECT":
			case "GROUP BY":
				loc.rule = "exprs";
				break;
			case "ORDER BY":
				loc.rule = "orderExprs";
				break;
			default:
				loc.rule = "expr";
		}
		
		// try to read from cache if turned on
		if (variables.cacheParse) {
		
			// create key for cache
			loc.cacheKey = Hash("#loc.rule#:#variables.parameterize#:#arguments.str#", Application.cfrel.HASH_ALGORITHM);
			
			// if key is in cache, just return cached parse tree
			if (inCache("parse", loc.cacheKey))
				return Duplicate(loadCache("parse", loc.cacheKey));
		}
		
		// break incoming string into tokens
		tokenize(arguments.str);

		// match against selected grammar rule
		var method = variables[loc.rule];
		loc.tree = method();
		
		// if tokens are still left, throw an error
		if (tokenIndex LTE tokenLen)
			throwException("Parsing error. Not all tokens processed. #tokenIndex - 1# of #tokenLen# processed.");
			
		// cache the parse tree in the application scope
		if (variables.cacheParse)
			saveCache("parse", loc.cacheKey, Duplicate(loc.tree));
		
		return loc.tree;
	</cfscript>
</cffunction>

<cffunction name="tokenize" returntype="void" access="private" hint="Turn a SQL string into an array of terminals">
	<cfargument name="str" type="string" required="true" />
	<cfscript>
		var loc = {};
		
		// regular expression for string and numeric literals
		loc.literalRegex = "('{ts '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'}'|'([^']*((\\|')'[^']*)*[^\'])?'|-?(\B|\b\d+)\.\d+\b|-?\b\d+\b)";
		
		// regular expression for all terminals (including literal placeholders)
		loc.terminalRegex = "::(dt|str|dec|int)::|\?|\.|,|\(|\)|\+|-|&|\^|\||\*|/|%|~|<=>|<=|>=|<>|!=|!>|!<|=|<|>|\b(AS|NOT|LIKE|BETWEEN|AND|OR|ASC|DESC|NULL|CAST|IS|IN|CASE|WHEN|THEN|ELSE|END|DISTINCT)\b|[\[""`]?(\w+)[""`\]]?";

		// extract literals (strings, numbers, dates, etc) out of the input string
		variables.literals = REMatch(loc.literalRegex, arguments.str);
		
		// replace literals with placeholders
		arguments.str = REReplaceNoCase(arguments.str, "'{ts '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'}'", "::dt::", "ALL");
		arguments.str = REReplaceNoCase(arguments.str, "'([^']*((\\|')'[^']*)*[^\'])?'", "::str::", "ALL");
		arguments.str = REReplaceNoCase(arguments.str, "-?(\B|\b\d+)\.\d+\b", "::dec::", "ALL");
		arguments.str = REReplaceNoCase(arguments.str, "-?\b\d+\b", "::int::", "ALL");
		
		// replace escaped identifiers with their unescaped values
		arguments.str = REReplace(arguments.str, "[\[""`]?(\w+)[""`\]]?", "\1", "ALL");
		
		// split string into tokens using using terminal pattern
		variables.tokens = REMatchNoCase(loc.terminalRegex, arguments.str);
		
		// set up counters for rest of parse
		variables.tokenIndex = 1;
		variables.tokenLen = ArrayLen(variables.tokens);
	</cfscript>
</cffunction>

<cffunction name="accept" returntype="boolean" access="private" hint="Return true if next item on stack matches string and increment pointer">
	<cfargument name="str" type="string" required="true" />
	<cfscript>
		if (tokenIndex LTE tokenLen AND tokens[tokenIndex] EQ arguments.str) {
			tokenIndex++;
			return true;
		}
		return false;
	</cfscript>
</cffunction>

<cffunction name="expect" returntype="boolean" access="private" hint="Accept next string item on stack or error out">
	<cfargument name="str" type="string" required="true" />
	<cfscript>
		if (NOT accept(arguments.str))
			throwException("Unexpected token found in SQL parse: #tokens[tokenIndex]#");
		return true;
	</cfscript>
</cffunction>

<cffunction name="acceptRegex" returntype="boolean" access="private" hint="Return true if next item on stack matches regex and increment pointer">
	<cfargument name="regex" type="string" required="true" />
	<cfscript>
		if (tokenIndex LTE tokenLen AND REFindNoCase("^(?:#arguments.regex#)$", tokens[tokenIndex]) GT 0) {
			tokenIndex++;
			return true;
		}
		return false;
	</cfscript>
</cffunction>

<cffunction name="expectRegex" returntype="boolean" access="private" hint="Accept next regex item on stack or error out">
	<cfargument name="regex" type="string" required="true" />
	<cfscript>
		if (NOT acceptRegex(arguments.regex))
			throwException("Unexpected token found in SQL parse: #tokens[tokenIndex]#");
		return true;
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
