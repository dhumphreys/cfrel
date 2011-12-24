<cfcomponent extends="tests.TestCase" output="false">
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
			variables.cfc = "src.Relation";
		</cfscript>
	</cffunction>
	
	<cffunction name="testParsingOfNullValues" type="void" access="public">
		<cfset assertEquals("NULL", new().parse("NULL")) />
	</cffunction>
	
	<cffunction name="testCommonGrammarParsingAndSql" type="void" access="public">
		<cfscript>
			// TODO: Add a complex example from each grammar node/rule
			var loc = {};
			loc.rel = new();
			loc.visitor = new src.visitors.Sql();
			loc.grammar = {};
			loc.grammar.paren = "(a + b != c)";
			loc.grammar.wildcard = "x.*";
			loc.grammar.column = "test.column";
			//loc.grammar.unaryOp = "-a";
			loc.grammar.binaryOp = "x + 5 = y * 7";
			loc.grammar.function = "dbo.greatest(x, 0)";
			loc.grammar.cast = "CAST(x AS DECIMAL(14,4))";
			loc.grammar.case = "CASE WHEN a > 0 THEN x WHEN a < 0 THEN y ELSE 0 END";
			for (loc.key in loc.grammar) {
				loc.parse = loc.rel.parse(loc.grammar[loc.key]);
				assertEquals("cfrel.nodes.#loc.key#", loc.parse.$class);
				assertEquals(loc.grammar[loc.key], loc.visitor.traverseToString(loc.parse));
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="testParsingOfEscapedQuotesInStrings" type="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = new();
			loc.visitor = new src.visitors.Sql();
			loc.test1 = "'ab'";
			loc.test2 = "'abc' = 'def'";
			loc.test3 = "'a''b''c'";
			loc.test4 = "'a\'b\'c\'d'";
			assertEquals(loc.test1, loc.rel.parse(loc.test1));
			assertEquals("cfrel.nodes.binaryOp", typeOf(loc.rel.parse(loc.test2)));
			assertEquals(loc.test2, loc.visitor.traverseToString(loc.rel.parse(loc.test2)));
			assertEquals(loc.test3, loc.rel.parse(loc.test3));
			assertEquals(loc.test4, loc.rel.parse(loc.test4));
		</cfscript>
	</cffunction>
	
	<cffunction name="testParameterizingOfLiterals" type="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = new();
			loc.rel2 = new(parameterize=true);
			loc.time = Now();
			loc.testTime = DateFormat(loc.time, "yyyy-mm-dd ") & TimeFormat(loc.time, "hh:mm:ss TT");
			assertEquals("'bob'", loc.rel.parse("'bob'"));
			assertEquals("5", loc.rel.parse("5"));
			assertEquals("1.2", loc.rel.parse("1.2"));
			assertEquals("-.9", loc.rel.parse("-.9"));
			assertEquals("'#loc.testTime#'", loc.rel.parse("'#loc.time#'"));
			assertEquals("cf_sql_varchar", loc.rel2.parse("'bob'").cfsqltype);
			assertEquals("cf_sql_integer", loc.rel2.parse("5").cfsqltype);
			assertEquals("cf_sql_decimal", loc.rel2.parse("1.2").cfsqltype);
			assertEquals("cf_sql_decimal", loc.rel2.parse("-.9").cfsqltype);
			assertEquals("cf_sql_timestamp", loc.rel2.parse("'#Now()#'").cfsqltype);
		</cfscript>
	</cffunction>
	
	<cffunction name="testThatStringParametersHaveQuotesStripped" type="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = new(parameterize=true);
			loc.time = Now();
			assertEquals(DateFormat(loc.time, "yyyy-mm-dd ") & TimeFormat(loc.time, "hh:mm:ss TT"), loc.rel.parse("'#loc.time#'").value);
			assertEquals("no quotes", loc.rel.parse("'no quotes'").value);
			assertEquals("it's a rule", loc.rel.parse("'it''s a rule'").value);
			assertEquals("it's a rule", loc.rel.parse("'it\'s a rule'").value);
		</cfscript>
	</cffunction>
</cfcomponent>