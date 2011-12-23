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
		
		// EXPR AS IDENTIFIER
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
		
		// if expression is a column, store it for use by positional parameters
		if (IsStruct(loc.left) AND loc.left.$class EQ "cfrel.nodes.Column") {
			if (IsStruct(loc.left.table) OR loc.left.table NEQ "")
				variables.tmpParamColumn = loc.left.table & "." & loc.left.column;
			else
				variables.tmpParamColumn = loc.left.column;
		}
		
		// ADD_EXPR BETWEEN TERM AND TERM
		if (accept(t.between)) {
			loc.start = term();
			expect(t.andOp);
			loc.left = sqlBetween(subject=loc.left, start=loc.start, end=term());
			
		} else if (accept(t.iss)) {
			
			// ADD_EXPR IS_NOT ADD_EXPR
			if (accept(t.neg))
				loc.left = sqlBinaryOp(left=loc.left, op="IS_NOT", right=addExpr());
				
			// ADD_EXPR IS ADD_EXPR
			else
				loc.left = sqlBinaryOp(left=loc.left, op="IS", right=addExpr());
			
		} else if (accept(t.neg)) {
					
			// ADD_EXPR NOT IN LPAREN EXPRS RPAREN
			if (accept(t.inn) AND expect(t.lparen)) {
				loc.e = sqlParen(subject=exprs());
				expect(t.rparen);
				loc.left = sqlBinaryOp(left=loc.left, op="NOT_IN", right=loc.e);
			}
					
			// ADD_EXPR NOT LIKE ADD_EXPR
			if (accept(t.like)) {
				loc.left = sqlBinaryOp(left=loc.left, op="NOT_LIKE", right=addExpr());
			}
			
		// ADD_EXPR IN LPAREN EXPRS RPAREN
		} else if (accept(t.inn) AND expect(t.lparen)) {
			loc.e = sqlParen(subject=exprs());
			expect(t.rparen);
			loc.left = sqlBinaryOp(left=loc.left, op="IN", right=loc.e);
			
		// ADD_EXPR COMPOP ADD_EXPR
		} else if (accept(t.compOp)) {
			loc.op = tokens[tokenIndex - 1];
			loc.left = sqlBinaryOp(left=loc.left, op=loc.op, right=addExpr());
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
		
		// NUMBER, TODO: implement parameterization
		if (accept(t.number)) {
			loc.term = popLiteral(); // wrap in nodes.literal?
		
		// STRING, TODO: implement parameterization
		} else if (accept(t.string)) {
			loc.term = popLiteral(); // wrap in nodes.literal?
		
		// DATE, TODO: implement parameterization
		} else if (accept(t.date)) {
			loc.date = REReplace(popLiteral(), "(^'|'$)", "", "ALL");
			loc.term = "'" & DateFormat(loc.date, "yyyy-mm-dd ") & TimeFormat(loc.date, "hh:mm:ss TT") & "'";
			
		// NULL
		} else if (accept(t.null)) {
			loc.term = "NULL"; // wrap in nodes.literal? or nodes.null?
			
		// WILDCARD
		} else if (accept(t.star)) {
			loc.term = sqlWildcard();
			
		// PARAM
		} else if (accept(t.param)) {
			if (NOT ArrayLen(variables.parseParameters))
				throwException("Not enough parameters were supplied for SQL expression.");
			loc.term = sqlParam(value=variables.parseParameters[1], column=variables.tmpParamColumn);
			ArrayDeleteAt(variables.parseParameters, 1);
			
		// UNARY TERM
		} else if (accept(t.unaryOp)) {
			loc.op = tokens[tokenIndex - 1];
			loc.e = term();
			loc.term = sqlUnaryOp(op=loc.op, subject=loc.e);
		
		// LPAREN EXPR RPAREN
		} else if (accept(t.lparen)) {
			loc.e = expr();
			expect(t.rparen);
			loc.term = sqlParen(subject=loc.e);
			
		// CAST LPAREN OR_CONDITION AS TYPE_NAME RPAREN
		} else if (accept(t.cast) AND expect(t.lparen)) {
			loc.e = orCondition();
			expect(t.as);
			loc.t = typeName();
			expect(t.rparen);
			loc.term = sqlCast(subject=loc.e, type=loc.t);
			
		// CASE
		} else if (peek(t.kase)) {
			loc.term = castStmt();
		
		} else if (expect(t.identifier)) {
			loc.id = tokens[tokenIndex - 1];
			
			// IDENTIFIER LPAREN OPT_EXPRS RPAREN
			if (accept(t.lparen)) {
				loc.distinct = (loc.id EQ "COUNT" AND accept(t.distinct));
				loc.args = optExprs();
				expect(t.rparen);
				loc.term = sqlFunction(name=loc.id, args=loc.args, distinct=loc.distinct);
			
			} else if (accept(t.dot)) {
			
				// IDENTIFIER DOT WILDCARD
				if (accept(t.star)) {
					loc.term = sqlWildcard(subject=loc.id);
				
				} else if (expect(t.identifier)) {
					loc.id2 = tokens[tokenIndex - 1];
					
					// IDENTIFIER DOT IDENTIFIER LPAREN OPT_EXPRS RPAREN				
					if (accept(t.lparen)) {
						loc.args = optExprs();
						expect(t.rparen);
						loc.term = sqlFunction(name=loc.id2, scope=sqlColumn(column=loc.id), args=loc.args);
						
					// TABLE DOT COLUMN
					} else {
						loc.term = sqlColumn(table=loc.id, column=loc.id2);
					}
				}
				
			// IDENTIFIER
			} else {
				loc.term = sqlColumn(column=loc.id);
			}
		}
		
		// TERM DOT IDENTIFIER LPAREN OPT_EXPRS RPAREN
		if (accept(t.dot) AND expect(t.identifier) AND expect(t.lparen)) {
			loc.id = tokens[tokenIndex - 2];
			loc.args = optExprs();
			expect(t.rparen);
			loc.term = sqlFunction(name=loc.id, scope=loc.term, args=loc.args);
		}
		
		return loc.term;
	</cfscript>
</cffunction>

<cffunction name="castStmt" returntype="any" access="private" hint="Match SQL case statement">
	<cfscript>
		var loc = {};
		loc.subject = "";
		loc.els = "";
		loc.cases = ArrayNew(1);
		
		// CASE
		if (expect(t.kase)) {
			
			// CASE EXPR
			if (NOT peek(t.when))
				loc.subject = expr();
				
			// WHEN EXPR THEN EXPR
			while (accept(t.when)) {
				loc.condition = expr();
				expect(t.then);
				ArrayAppend(loc.cases, sqlCaseCondition(condition=loc.condition, subject=expr()));
			}
			
			// ELSE EXPR
			if (accept(t.els))
				loc.els = expr();
				
			// END
			expect(t.end);
			return sqlCase(subject=loc.subject, cases=loc.cases, els=loc.els);
		}
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
