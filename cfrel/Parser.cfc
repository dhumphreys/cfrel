<cfcomponent output="false">
	<cfinclude template="functions.cfm" />
	
	<cffunction name="init" returntype="struct" access="public" hint="Constructor">
		<cfscript>
			var loc = {};
			
			// string and numeric literals
			variables.l = {string="'[^']*'", number="\b-?\d+(\.\d+)?\b"};
			
			// build regex to match literals
			variables.literalRegex = "(#l.string#|#l.number#)";
			
			// terminals (and literal placeholders)
			variables.t = {string="::string::", number="::number::", param="\?", dot="\.", comma=",",
				lparen="\(", rparen="\)", addOp="\+|-|&|\^|\|", star="\*", mulOp="\*|/|%", as="\bAS\b",
				unaryOp="\+|-|~|\bNOT\b", compOp="<=>|<=|>=|<>|!=|!>|!<|=|<|>|\bLIKE\b", between="\bBETWEEN\b",
				andOp="\bAND\b", orOp="\bOR\b", neg="\bNOT\b", sortOp="\bASC\b|\bDESC\b", null="\bNULL\b",
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
		<cfargument name="clause" type="string" default="WHERE" />
		<cfscript>
			var loc = {};
			tokenize(arguments.str);
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
			if (tokenIndex LTE tokenLen)
				throwException("Parsing error. Not all tokens processed. #tokenIndex - 1# of #tokenLen# processed.");
			return loc.tree;
		</cfscript>
	</cffunction>
	
	<!-----------------------
	--- Grammar Functions ---
	------------------------>
	
	<cffunction name="optExprs" returntype="any" access="private" hint="Match optional list of expressions in grammar">
		<cfscript>
			if (NOT peek(t.rparen))
				return exprs();
			return [];
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
	
	<cffunction name="expr" returntype="any" access="private" hint="Match an expression in grammer">
		<cfscript>
			var loc = {};
			loc.expr = orCondition();
			if (accept(t.as) AND expect(t.identifier))
				return sqlAlias(subject=loc.expr, alias=tokens[tokenIndex - 1]);
			return loc.expr;
		</cfscript>
	</cffunction>
	
	<cffunction name="orCondition" returntype="any" access="private" hint="Match OR condition in grammar">
		<cfscript>
			var loc = {};
			loc.left = andCondition();
			
			// AND_CONDITION OR OR_CONDITION
			if (accept(t.orOp))
				return sqlBinaryOp(left=loc.left, op="OR", right=orCondition());
			
			// AND_CONDITION
			return loc.left;
		</cfscript>
	</cffunction>
	
	<cffunction name="andCondition" returntype="any" access="private" hint="Match AND condition in grammar">
		<cfscript>
			var loc = {};
			loc.left = notExpr();
		
			// NOT_EXPR AND AND_CONDITION
			if (accept(t.andOp))
				return sqlBinaryOp(left=loc.left, op="AND", right=andCondition());
			
			// NOT_EXPR
			return loc.left;
		</cfscript>
	</cffunction>
	
	<cffunction name="notExpr" returntype="any" access="private" hint="Match NOT expression in grammar">
		<cfscript>
			
			// NOT COMP_EXPR
			if (accept(t.neg))
				return sqlUnaryOp(subject=compExpr(), op="NOT");
			
			// COMP_EXPR
			return compExpr();
		</cfscript>
	</cffunction>
	
	<cffunction name="compExpr" returntype="any" access="private" hint="Match comparison in grammar">
		<cfscript>
			var loc = {};
			loc.left = addExpr();
			
			// ADD_EXPR BETWEEN TERM AND TERM
			if (accept(t.between)) {
				loc.start = term();
				expect(t.andOp);
				return sqlBetween(subject=loc.left, start=loc.start, end=term());
				
			} else if (accept(t.iss)) {
				
				// ADD_EXPR IS_NOT ADD_EXPR
				if (accept(t.neg))
					return sqlBinaryOp(left=loc.left, op="IS_NOT", right=addExpr());
					
				// ADD_EXPR IS ADD_EXPR
				else
					return sqlBinaryOp(left=loc.left, op="IS", right=addExpr());
				
			// ADD_EXPR IN LPAREN EXPRS RPAREN
			} else if (accept(t.inn) AND expect(t.lparen)) {
				loc.e = sqlParen(subject=exprs());
				expect(t.rparen);
				return sqlBinaryOp(left=loc.left, op="IN", right=loc.e);
				
			// ADD_EXPR COMPOP ADD_EXPR
			} else if (accept(t.compOp)) {
				loc.op = tokens[tokenIndex - 1];
				return sqlBinaryOp(left=loc.left, op=loc.op, right=addExpr());
			}
			
			// ADD-EXPR
			return loc.left;
		</cfscript>
	</cffunction>
	
	<cffunction name="addExpr" returntype="any" access="private" hint="Match add/subtract expression in grammar">
		<cfscript>
			var loc = {};
			loc.left = mulExpr();
			
			// MUL_EXPR ADD_OP ADD_EXPR
			if (accept(t.addOp)) {
				loc.op = tokens[tokenIndex - 1];
				return sqlBinaryOp(left=loc.left, op=loc.op, right=addExpr());
			}
			
			// MUL_EXPR
			return loc.left;
		</cfscript>
	</cffunction>
	
	<cffunction name="mulExpr" returntype="any" access="private" hint="Match multiplication/division expression in grammar">
		<cfscript>
			var loc = {};
			loc.left = term();
			
			// TERM MUL_OP MUL_EXPR
			if (accept(t.mulOp)) {
				loc.op = tokens[tokenIndex - 1];
				return sqlBinaryOp(left=loc.left, op=loc.op, right=mulExpr());
			}
			
			// TERM
			return loc.left;
		</cfscript>
	</cffunction>
	
	<cffunction name="term" returntype="any" access="private" hint="Match term in grammar">
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
			} else if (accept(t.star)) {
				return sqlWildcard();
				
			// PARAM
			} else if (accept(t.param)) {
				return "?"; // todo: object? wrap in nodes.literal?
				
			// UNARY TERM
			} else if (accept(t.unaryOp)) {
				loc.op = tokens[tokenIndex - 1];
				loc.e = term();
				return sqlUnaryOp(op=loc.op, subject=loc.e);
			
			// LPAREN EXPR RPAREN
			} else if (accept(t.lparen)) {
				loc.e = expr();
				expect(t.rparen);
				return sqlParen(subject=loc.e);
				
			// CAST LPAREN EXPR AS TYPE_NAME RPAREN
			} else if (accept(t.cast) AND expect(t.lparen)) {
				loc.e = expr();
				expect(t.as);
				loc.t = typeName();
				expect(t.rparen);
				return sqlCast(subject=loc.e, type=loc.t);
			
			} else if (accept(t.identifier)) {
				loc.id = tokens[tokenIndex - 1];
				
				// IDENTIFIER LPAREN OPT_EXPRS RPAREN
				if (accept(t.lparen)) {
					loc.args = optExprs();
					expect(t.rparen);
					return sqlFunction(name=loc.id, args=loc.args);
					
				// IDENTIFIER
				} else {
					loc.c = sqlColumn(column=loc.id);
					return loc.c;
				}
			}
			throwException("Invalid expression during SQL parse.");
		</cfscript>
	</cffunction>
	
	<cffunction name="typeName" returntype="any" access="private" hint="Match type name in grammar">
		<cfscript>
			var loc = {num1="", num2=""};
			if (accept(t.identifier)) {
				loc.id = tokens[tokenIndex - 1];
				if (accept(t.lparen) AND expect(t.number)) {
					loc.num1 = popLiteral();
					if (accept(t.comma) AND expect(t.number))
						loc.num2 = popLiteral();
					expect(t.rparen);
				}
				return sqlType(name=loc.id, val1=loc.num1, val2=loc.num2);
			}
			return false;
		</cfscript>
	</cffunction>
	
	<cffunction name="orderExprs" returntype="any" access="private" hint="Match a list of order bys in grammar">
		<cfscript>
			var loc = {};
			loc.orders = [];
			ArrayAppend(loc.orders, orderExpr());
			while (accept(t.comma))
				ArrayAppend(loc.orders, orderExpr());
			return loc.orders;
		</cfscript>
	</cffunction>
	
	<cffunction name="orderExpr" returntype="any" access="private" hint="Match order by in grammar">
		<cfscript>
			var loc = {};
			loc.expr = expr();
			loc.desc = false;
			if (accept(t.sortOp))
				loc.desc = (tokens[tokenIndex - 1] EQ "DESC");
			return sqlOrder(subject=loc.expr, descending=loc.desc);
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