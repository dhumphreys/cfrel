<cffunction name="optExprs" returntype="any" access="private" hint="Match optional list of expressions in grammar">
	<cfscript>
		if (tokens[tokenIndex] NEQ ")")
			return exprs();
		return [];
	</cfscript>
</cffunction>

<cffunction name="exprs" returntype="any" access="private" hint="Match a list of expressions in grammar">
	<cfscript>
		var loc = {};
		loc.exprs = [];
		ArrayAppend(loc.exprs, expr());
		while (accept(","))
			ArrayAppend(loc.exprs, expr());
		return loc.exprs;
	</cfscript>
</cffunction>

<cffunction name="expr" returntype="any" access="private" hint="Match an expression in grammer">
	<cfscript>
		var loc = {};
		loc.expr = orCondition();
		
		// EXPR AS IDENTIFIER
		if (accept("AS") AND expectRegex("[\[""`]?(\w+)[""`\]]?")) {
			if (IsStruct(loc.expr) AND loc.expr.$class EQ "cfrel.nodes.column")
				loc.expr.alias = tokens[tokenIndex - 1];
			else
				return sqlAlias(subject=loc.expr, alias=tokens[tokenIndex - 1]);
		}
		
		return loc.expr;
	</cfscript>
</cffunction>

<cffunction name="orCondition" returntype="any" access="private" hint="Match OR condition in grammar">
	<cfscript>
		var loc = {};
		loc.left = andCondition();
		
		// AND_CONDITION OR OR_CONDITION
		if (accept("OR"))
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
		if (accept("AND"))
			return sqlBinaryOp(left=loc.left, op="AND", right=andCondition());
		
		// NOT_EXPR
		return loc.left;
	</cfscript>
</cffunction>

<cffunction name="notExpr" returntype="any" access="private" hint="Match NOT expression in grammar">
	<cfscript>
		
		// NOT COMP_EXPR
		if (accept("NOT"))
			return sqlUnaryOp(subject=compExpr(), op="NOT");
		
		// COMP_EXPR
		return compExpr();
	</cfscript>
</cffunction>

<cffunction name="compExpr" returntype="any" access="private" hint="Match comparison in grammar">
	<cfscript>
		var loc = {};
		loc.left = addExpr();
		
		// if expression is a column, store it for use by positional parameters
		if (IsStruct(loc.left) AND loc.left.$class EQ "cfrel.nodes.Column")
			variables.tmpParamColumn = loc.left.column;

		// pop the next token if available
		if (tokenIndex LTE tokenLen) {
			loc.token = tokens[tokenIndex++];
			switch (loc.token) {
			
				// ADD_EXPR BETWEEN TERM AND TERM
				case "BETWEEN":
					loc.start = term();
					expect("AND");
					loc.left = sqlBetween(subject=loc.left, start=loc.start, end=term());
					break;
					
				case "IS":

					// ADD_EXPR IS_NOT ADD_EXPR
					if (accept("NOT"))
						loc.left = sqlBinaryOp(left=loc.left, op="IS_NOT", right=addExpr());
						
					// ADD_EXPR IS ADD_EXPR
					else
						loc.left = sqlBinaryOp(left=loc.left, op="IS", right=addExpr());

					break;
					
				case "NOT":
							
					// ADD_EXPR NOT IN LPAREN EXPRS RPAREN
					if (accept("IN")) {
						expect("(");
						loc.e = exprs();
						expect(")");
						loc.left = sqlBinaryOp(left=loc.left, op="NOT_IN", right=loc.e);

					// ADD_EXPR NOT LIKE ADD_EXPR
					} else if (expect("LIKE")) {
						loc.left = sqlBinaryOp(left=loc.left, op="NOT_LIKE", right=addExpr());
					}

					break;
					
				// ADD_EXPR IN LPAREN EXPRS RPAREN
				case "IN":
					expect("(");
					loc.e = exprs();
					expect(")");
					loc.left = sqlBinaryOp(left=loc.left, op="IN", right=loc.e);
					break;
					
				// ADD_EXPR COMPOP ADD_EXPR
				case "=": case "<": case ">": case "LIKE": case "<=": case ">=":
				case "<>": case "!=": case "!>": case "!<": case "<=>":
					loc.left = sqlBinaryOp(left=loc.left, op=loc.token, right=addExpr());
					break;

				// backtrack to previous token
				default:
					tokenIndex -= 1;
			}
		}
		
		// unset column used for parameters
		variables.tmpParamColumn = "";
		
		return loc.left;
	</cfscript>
</cffunction>

<cffunction name="addExpr" returntype="any" access="private" hint="Match add/subtract expression in grammar">
	<cfscript>
		var loc = {};
		loc.left = mulExpr();
		
		// MUL_EXPR ADD_OP ADD_EXPR
		if (tokenIndex LTE tokenLen AND Find(tokens[tokenIndex], "+-&^|")) {
			loc.op = tokens[tokenIndex++];
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
		if (tokenIndex LTE tokenLen AND Find(tokens[tokenIndex], "*/%")) {
			loc.op = tokens[tokenIndex++];
			return sqlBinaryOp(left=loc.left, op=loc.op, right=mulExpr());
		}
		
		// TERM
		return loc.left;
	</cfscript>
</cffunction>

<cffunction name="term" returntype="any" access="private" hint="Match term in grammar">
	<cfscript>
		var loc = {};

		// read the next token
		loc.token = tokens[tokenIndex++];
		switch (loc.token) {

			// DECIMAL
			case "::dec::":
				loc.term = popLiteral();
				if (variables.parameterize)
					loc.term = sqlParam(value=loc.term, cfsqltype="cf_sql_decimal", column=variables.tmpParamColumn);
				break;

			// INTEGER
			case "::int::":
				loc.term = popLiteral();
				if (variables.parameterize)
					loc.term = sqlParam(value=loc.term, cfsqltype="cf_sql_integer", column=variables.tmpParamColumn);
				break;
			
			// STRING
			case "::str::":
				loc.term = popLiteral();
				if (variables.parameterize) {
					loc.term = REReplace(loc.term, "^'(.*)'$", "\1");
					loc.term = REReplace(loc.term, "(\\|')'", "'", "ALL");
					loc.term = sqlParam(value=loc.term, cfsqltype="cf_sql_varchar", column=variables.tmpParamColumn);
				}
				break;
			
			// DATE
			case "::dt::":
				loc.date = REReplace(popLiteral(), "(^'|'$)", "", "ALL");
				loc.term = "'" & DateFormat(loc.date, "yyyy-mm-dd ") & TimeFormat(loc.date, "hh:mm:ss TT") & "'";
				if (variables.parameterize) {
					loc.term = REReplace(loc.term, "^'(.+)'$", "\1");
					loc.term = sqlParam(value=loc.term, cfsqltype="cf_sql_timestamp", column=variables.tmpParamColumn);
				}
				break;
				
			// NULL
			case "NULL":
				loc.term = "NULL"; // wrap in nodes.literal? or nodes.null?
				break;
				
			// WILDCARD
			case "*":
				loc.term = sqlWildcard();
				break;
				
			// PARAM
			case "?":
				loc.term = sqlParam(column=variables.tmpParamColumn);
				break;
				
			// UNARY TERM
			case "+": case "-": case "~": case "NOT":
				loc.term = sqlUnaryOp(op=loc.token, subject=term());
				break;
			
			// LPAREN EXPR RPAREN
			case "(":
				loc.e = expr();
				expect(")");
				loc.term = sqlParen(subject=loc.e);
				break;
				
			// CAST LPAREN OR_CONDITION AS TYPE_NAME RPAREN
			case "CAST":
				expect("(");
				loc.e = orCondition();
				expect("AS");
				loc.t = typeName();
				expect(")");
				loc.term = sqlCast(subject=loc.e, type=loc.t);
				break;
				
			// CASE
			case "CASE":
				tokenIndex--;
				loc.term = caseStmt();
				break;
			
			default:
				tokenIndex--;
				expectRegex("[\[""`]?(\w+)[""`\]]?");
				loc.id = loc.token;
				
				// IDENTIFIER LPAREN OPT_EXPRS RPAREN
				if (accept("(")) {
					loc.distinct = (loc.id EQ "COUNT" AND accept("DISTINCT"));
					loc.args = optExprs();
					expect(")");
					loc.term = sqlFunction(name=loc.id, args=loc.args, distinct=loc.distinct);
				
				} else if (accept(".")) {
				
					// IDENTIFIER DOT WILDCARD
					if (accept("*")) {
						loc.term = sqlWildcard(subject=loc.id);
					
					} else if (expectRegex("[\[""`]?(\w+)[""`\]]?")) {
						loc.id2 = tokens[tokenIndex - 1];
						
						// IDENTIFIER DOT IDENTIFIER LPAREN OPT_EXPRS RPAREN				
						if (accept("(")) {
							loc.args = optExprs();
							expect(")");
							loc.term = sqlFunction(name=loc.id2, scope=sqlColumn(column=loc.id), args=loc.args);
							
						// TABLE DOT COLUMN
						} else {
							loc.term = sqlColumn(column=ListAppend(loc.id, loc.id2, "."));
						}
					}
					
				// IDENTIFIER
				} else {
					loc.term = sqlColumn(column=loc.id);
				}
		}
		
		// TERM DOT IDENTIFIER LPAREN OPT_EXPRS RPAREN
		if (accept(".") AND expectRegex("[\[""`]?(\w+)[""`\]]?") AND expect("(")) {
			loc.id = tokens[tokenIndex - 2];
			loc.args = optExprs();
			expect(")");
			loc.term = sqlFunction(name=loc.id, scope=loc.term, args=loc.args);
		}
		
		return loc.term;
	</cfscript>
</cffunction>

<cffunction name="caseStmt" returntype="any" access="private" hint="Match SQL case statement">
	<cfscript>
		var loc = {};
		loc.subject = "";
		loc.els = "";
		loc.cases = ArrayNew(1);
		
		// CASE
		if (expect("CASE")) {
			
			// CASE EXPR
			if (tokens[tokenIndex] NEQ "WHEN")
				loc.subject = expr();
				
			// WHEN EXPR THEN EXPR
			while (accept("WHEN")) {
				loc.condition = expr();
				expect("THEN");
				ArrayAppend(loc.cases, sqlCaseCondition(condition=loc.condition, subject=expr()));
			}
			
			// ELSE EXPR
			if (accept("ELSE"))
				loc.els = expr();
				
			// END
			expect("END");
			return sqlCase(subject=loc.subject, cases=loc.cases, els=loc.els);
		}
	</cfscript>
</cffunction>

<cffunction name="typeName" returntype="any" access="private" hint="Match type name in grammar">
	<cfscript>
		var loc = {num1="", num2=""};
		if (acceptRegex("[\[""`]?(\w+)[""`\]]?")) {
			loc.id = tokens[tokenIndex - 1];
			if (accept("(") AND expect("::int::")) {
				loc.num1 = popLiteral();
				if (accept(",") AND expect("::int::"))
					loc.num2 = popLiteral();
				expect(")");
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
		while (accept(","))
			ArrayAppend(loc.orders, orderExpr());
		return loc.orders;
	</cfscript>
</cffunction>

<cffunction name="orderExpr" returntype="any" access="private" hint="Match order by in grammar">
	<cfscript>
		var loc = {};
		loc.expr = expr();
		if (accept("DESC"))
			loc.desc = true;
		else if (accept("ASC"))
			loc.desc = false;
		else
			loc.desc = false;
		return sqlOrder(subject=loc.expr, descending=loc.desc);
	</cfscript>
</cffunction>
