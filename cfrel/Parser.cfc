<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfscript>
			var loc = {};
			
			// string and numeric literals
			variables.l = {string="'[^']*'", number="\b-?\d+(.\d+)?\b"};
			
			// build regex to match literals
			variables.literalRegex = "(#l.string#|#l.number#)";
			
			// terminals (and literal placeholders)
			variables.t = {string="::string::", number="::number::", param="\?", dot="\.", comma=",",
				lparen="\(", rparen="\)", addOp="\+|-", mulOp="\*", divOp="/", as="\bAS\b",
				compOp="=|<|>|<=|>=|<>|!=|\bLIKE\b", between="\bBETWEEN\b", andOp="\bAND\b",
				orOp="\bOR\b", neg="\bNOT\b", sortOp="\bASC|DESC\b", null="\bNULL\b",
				cast="\bCAST\b", iss="\bIS\b", inn="\bIN\b", identifier="\w+"};
			
			// build regex to match any of the terminals above
			variables.terminalRegex = "";
			for (loc.key in variables.t)
				terminalRegex = ListAppend(terminalRegex, t[loc.key], "|");
					
			// token and literal storage
			variables.tokens = [];
			variables.tokenTypes = [];
			variables.literals = [];
			
			// token index during parse
			variables.tokenIndex = 1;
			variables.tokenLen = 0;
			
			return this;
		</cfscript>
	</cffunction>
	
	<!---------------------------
	--- Core Parsing Function ---
	---------------------------->
	
	<cffunction name="parse" returntype="any" access="public" hint="Turn a SQL string into a tree of nodes">
		<cfargument name="str" type="string" required="true" />
		<cfargument name="type" type="string" default="expression" />
		<cfscript>
			var loc = {};
			tokenize(arguments.str);
			switch (arguments.type) {
				case "condition":
					loc.tree = orCondition();
					break;
				default:
					loc.tree = expr();
			}
			if (tokenIndex LTE tokenLen)
				throwException("Parsing error. Not all tokens processed. #tokenIndex - 1# of #tokenLen# processed.");
			return loc.tree;
		</cfscript>
	</cffunction>
	
	<!-----------------------
	--- Grammar Functions ---
	------------------------>
	
	<cffunction name="orCondition" returntype="any" access="private" hint="Match OR condition in grammar">
		<cfscript>
			var loc = {};
			loc.left = andCondition();
			
			// AND_CONDITION OR OR_CONDITION
			if (accept(t.orOp)) {
				loc.right = orCondition();
				return sqlBinaryOp(left=loc.left, op="OR", right=loc.right);
			}
			
			// AND_CONDITION
			return loc.left;
		</cfscript>
	</cffunction>
	
	<cffunction name="andCondition" returntype="any" access="private" hint="Match AND condition in grammar">
		<cfscript>
			var loc = {};
			
			// LPAREN OR_CONDITION RPAREN
			if (accept(t.lparen)) {
				loc.cond = orCondition();
				expect(t.rparen);
				return loc.cond;
				
			} else {
				loc.left = comp();
			
				// COMP AND AND_CONDITION
				if (accept(t.andOp)) {
					loc.right = andCondition();
					return sqlBinaryOp(left=loc.left, op="AND", right=loc.right);	
				}
				
				// COMP
				return loc.left;
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="comp" returntype="any" access="private" hint="Match comparison in grammar">
		<cfscript>
			var loc = {};
			loc.left = expr();
			
			// EXPR BETWEEN EXPR AND EXPR
			if (accept(t.between)) {
				loc.start = expr();
				expect(t.andOp);
				loc.end = expr();
				
			} else if (accept(t.iss)) {
				
				// EXPR IS_NOT EXPR
				if (accept(t.neg)) {
					loc.right = expr();
					return sqlBinaryOp(left=loc.left, op="IS_NOT", right="NULL");
					
				// EXPR IS EXPR
				} else {
					loc.right = expr();
					return sqlBinaryOp(left=loc.left, op="IS", right=loc.right);
				}
				
			// EXPR IN LPAREN EXPRS RPAREN
			} else if (accept(t.inn) AND expect(t.lparen)) {
				loc.e = exprs();
				expect(t.rparen);
				return sqlBinaryOp(left=loc.left, op="IN", right=loc.e);
				
			// EXPR COMPOP EXPR
			} else {
				expect(t.compOp);
				loc.op = tokens[tokenIndex - 1];
				loc.right = expr();
				return sqlBinaryOp(left=loc.left, op=loc.op, right=loc.right);
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="exprs" returntype="any" access="private" hint="Match a list of expressions in grammar">
		<cfscript>
			var loc = {};
			loc.exprs = [];
			ArrayAppend(loc.exprs, expr());
			while (accept(t.comma))
				ArrayAppend(loc.exprs, expr());
			return loc.exprs;
		</cfscript>
	</cffunction>
	
	<cffunction name="expr" returntype="any" access="private" hint="Match expression in grammar">
		<cfscript>
			var loc = {};
			
			// NUMBER
			if (accept(t.number)) {
				return popLiteral(); // wrap in nodes.literal?
			
			// STRING
			} else if (accept(t.string)) {
				return popLiteral(); // wrap in nodes.literal?
				
			// NULL
			} else if (accept(t.null)) {
				return "NULL"; // wrap in nodes.literal? or nodes.null?
				
			// WILDCARD
			} else if (accept(t.mulop)) {
				return sqlWildcard();
				
			// PARAM
			} else if (accept(t.param)) {
				return "?"; // todo: object
				
			// NOT EXPR
			} else if (accept(t.neg)) {
				loc.e = expr();
				return sqlUnaryOp(op="NOT", subject=loc.e);
			
			// LPAREN EXPR RPAREN
			} else if (accept(t.lparen)) {
				loc.e = expr();
				expect(t.rparen);
				if (accept(t.as)) {
					expect(t.identifier);
					return sqlExpression(subject=loc.e, alias=tokens[tokenIndex - 1]);
				}
				return loc.e;
			
			} else if (accept(t.identifier)) {
				
				// FUNC
				if (peek(t.lparen)) {
					tokenIndex -= 1;
					loc.f = func();
					if (accept(t.as)) {
						expect(t.identifier);
						return sqlExpression(subject=loc.f, alias=tokens[tokenIndex - 1]);
					}
					return loc.f;
					
				// IDENTIFIER
				} else {
					loc.c = sqlColumn(column=tokens[tokenIndex - 1]);
					if (accept(t.as)) {
						expect(t.identifier);
						loc.c.alias = tokens[tokenIndex - 1];
					}
					return loc.c;
				}
			}
			throwException("Invalid expression during SQL parse.");
		</cfscript>
	</cffunction>
	
	<cffunction name="func" returntype="any" access="private" hint="Match function call in grammar">
		<cfscript>
			var loc = {};
			
			// IDENTIFIER LPAREN OPT_ARGS RPAREN
			if (accept(t.identifier) AND expect(t.lparen)) {
				loc.id = tokens[tokenIndex - 2];
				loc.a = funcArgs();
				expect(t.rparen);
				return sqlFunction(name=loc.id, args=loc.a);
			}
			return false;
		</cfscript>
	</cffunction>
	
	<cffunction name="funcArgs" returntype="any" access="private" hint="Match list of function parameters in grammar">
		<cfscript>
			var loc = {};
			loc.args = [];
			if (NOT peek(t.rparen)) {
				do {
					ArrayAppend(loc.args, expr());
				} while (accept(t.comma));
			}
			return loc.args;
		</cfscript>
	</cffunction>
	
	<!-----------------------
	--- Control Functions ---
	------------------------>
	
	<cffunction name="peek" returntype="boolean" access="private" hint="See if next item on token stack matches regex">
		<cfargument name="regex" type="string" required="true" />
		<cfargument name="offset" type="numeric" default="0" />
		<cfscript>
			if (tokenIndex + arguments.offset GT tokenLen)
				return false;
			return (REFindNoCase("^#arguments.regex#$", tokens[tokenIndex + arguments.offset]) GT 0);
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
	
	<cffunction name="popLiteral" returntype="numeric" access="private" hint="Pop the next literal string or number of the literals stack">
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
	
	<!------------------------
	--- Tokenizer Function ---
	------------------------->
	
	<cffunction name="tokenize" returntype="void" access="private" hint="Turn a SQL string into an array of terminals">
		<cfargument name="str" type="string" required="true" />
		<cfscript>
			var loc = {};
			
			// match against string terminals
			loc.start = 1;
			loc.matches = REFindNoCase(literalRegex, arguments.str, loc.start, true);
			while (loc.matches.pos[1] GT 0) {
				
				// grab substring
				loc.match = Mid(arguments.str, loc.matches.pos[1], loc.matches.len[1]);
				
				// place match in literal array
				ArrayAppend(variables.literals, loc.match);
				
				// get new start position for search
				loc.start = loc.matches.pos[1] + loc.matches.len[1];
			
				// match against more string terminals
				loc.matches = REFindNoCase(literalRegex, arguments.str, loc.start, true);
			}
			
			// replace literals with placeholders
			arguments.str = REReplaceNoCase(arguments.str, l.string, t.string, "ALL");
			arguments.str = REReplaceNoCase(arguments.str, l.number, t.number, "ALL");
			
			// pad symbols with spaces and replace consecutive spaces
			arguments.str = REReplaceNoCase(arguments.str, "(#terminalRegex#)", " \1 ", "ALL");
			arguments.str = Trim(REReplaceNoCase(arguments.str, "(\s+)", " ", "ALL"));
			
			// split string into tokens by spaces
			variables.tokens = ListToArray(arguments.str, " ");
			
			// set up counters for rest of parse
			variables.tokenIndex = 1;
			variables.tokenLen = ArrayLen(variables.tokens);
		</cfscript>
	</cffunction>
</cfcomponent>