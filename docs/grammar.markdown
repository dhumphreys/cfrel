# SQL Grammar

This is the grammar used to parse SQL strings into trees of cfrel.nodes.Node sub-classes. The code for each of these is available in the cfrel.Parser class, which acts as a recursive descent parser.

## Non-Terminals

* EXPR
	* NUMBER
	* STRING
	* NULL
	* WILDCARD
	* PARAM
	* NOT EXPR
	* LPAREN EXPR RPAREN
	* FUNC
	* IDENTIFIER

* EXPRS
	* EXPR
	* EXPR COMMA EXPRS

* FUNC
	* IDENTIFIER LPAREN ARGS RPAREN

* ARGS
	* EXPR
	* EXPR COMMA ARGS

* OR-CONDITION
	* AND-CONDITION
	* AND-CONDITION OR OR-CONDITION

* AND-CONDITION
	* LPAREN OR-CONDITION RPAREN
	* COMP
	* COMP AND AND-CONDITION

* COMP	
	* EXPR BETWEEN EXPR AND EXPR
	* EXPR IS-NOT EXPR
	* EXPR IS EXPR
	* EXPR IN LPAREN EXPRS RPAREN
	* EXPR COMPOP EXPR
