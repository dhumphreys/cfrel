<!--------------------------------------
--- Run this to create test database ---
--------------------------------------->

<cfquery name="createUsers" datasource="cfrel">
	CREATE TABLE users (
		id INT PRIMARY_KEY AUTO_INCREMENT NOT NULL,
		username VARCHAR(20) NOT NULL,
		password VARCHAR(32) NOT NULL
	)
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (1, "anne", "apple")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (2, "bobby", "ball")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (3, "carson", "cat")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (4, "donnie", "dog")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (5, "edward", "egg")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (6, "franklin", "fish")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (7, "gale", "grass")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (8, "hellen", "house")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (9, "ingrid", "iglou")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (10, "joe", "jacket")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (11, "kelly", "kerosine")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (12, "lynn", "leopard")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (13, "michael", "machete")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (14, "nicki", "nervous")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (15, "omar", "olympics")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (16, "phillip", "pacific")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (17, "quincy", "quarter")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (18, "rene", "ranch")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (19, "sally", "season")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (20, "terrance", "traffic")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (21, "ursula", "umbrella")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (22, "vance", "vendetta")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (23, "wallie", "wedding")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (24, "xavier", "x-ray")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (25, "yvonne", "yahoo")
</cfquery>
<cfquery datasource="cfrel">
	INSERT INTO users VALUES (26, "ziggy", "zebra")
</cfquery>