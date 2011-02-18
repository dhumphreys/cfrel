<cfcomponent extends="tests.TestCase" output="false">
	
	<cffunction name="setup" returntype="void" access="public">
		<cfscript>
			super.setup();
		</cfscript>
	</cffunction>
	
	<cffunction name="testLiteral" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.node = sqlLiteral("ROW_NUMBER()");
			assertEquals("cfrel.nodes.Literal", typeOf(loc.node));
			assertEquals("ROW_NUMBER()", loc.node.subject, "Literal node should be constructed with correct value");
		</cfscript>
	</cffunction>
	
	<cffunction name="testRelation" returntype="void" access="public">
		<cfscript>
			var loc = {};
			loc.rel = relation(datasource="cfrel", visitor="SqlServer");
			assertIsTypeOf(loc.rel, "cfrel.Relation");
			assertIsTypeOf(loc.rel.visitor, "cfrel.visitors.SqlServer");
			assertEquals("cfrel", loc.rel.datasource);
		</cfscript>
	</cffunction>
	
	<cffunction name="testThrowException" returntype="void" access="public">
		<cfscript>
			var pass = false;
			try {
				throwException("Test Throw");
			} catch (custom_type e) {
				pass = true;
			}
			assertTrue(pass, "throwException() should have thrown an exception.");
		</cfscript>
	</cffunction>
	
	<cffunction name="testTypeOf" returntype="void" access="public">
		<cfscript>
			assertEquals("array", typeOf([]));
			assertEquals("query", typeOf(QueryNew('')));
			assertEquals("struct", typeOf({}));
			assertEquals("binary", typeOf(ToBinary(ToBase64("1234"))));
			assertEquals("function", typeOf(sqlLiteral));
			assertEquals("cfrel.nodes.Literal", typeOf(sqlLiteral("SELECT a FROM b")));
		</cfscript>
	</cffunction>
	
	<cffunction name="testAddCfcPrefix" returntype="void" access="public">
		<cfscript>
			assertEquals("com.component", addCfcPrefix("com.component"));
			application.cfrel.cfcPrefix = "something";
			assertEquals("something.com.component", addCfcPrefix("com.component"));
			StructDelete(application, "cfrel", false);
		</cfscript>
	</cffunction>
	
	<cffunction name="testStripCfcPrefix" returntype="void" access="public">
		<cfscript>
			assertEquals("com.component", stripCfcPrefix("com.component"));
			application.cfrel.cfcPrefix = "something";
			assertEquals("com.component", stripCfcPrefix("something.com.component"));
			StructDelete(application, "cfrel", false);
		</cfscript>
	</cffunction>
	
</cfcomponent>