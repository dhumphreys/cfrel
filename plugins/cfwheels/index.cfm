<h1>CFRel</h1>
<p>You have installed the CFRel plugin. CFRel aims to enhance your SELECT queries by providing more intelligent query construction and ARel (Rails 3) style syntax for your queries.</p>
<p>For the simplest example, the following code:</p>
<pre>
// simple wheels query
query = model("table1").findAll(
	select="id,name",
	include="table2,table3",
	where="id = #params.id#",
	order="name ASC",
	page=1,
	perPage=10
);
</pre>
<p>can be converted to:</p>
<pre>
// simple cfrel query
query = model("table1")
	.select("id,name")
	.include("table2,table3")
	.where(id=params.id)
	.order("name ASC")
	.paginate(1, 10)
	.query();
</pre>
<p>All method calls are chainable until <code>query()</code> is called. Additional functionality, such as easily performing query-of-queries on recordsets, loading structs/objects through relations, loop control, and finding through relations are also available.</p>
<pre>
// simple query to get first 100 records by rating
// NOTE: we are still dealing with a relation object
items = model("item").order("rating DESC").limit(1000);

// loop over query printing out dumps of objects
// NOTE: query is lazy executed now that we are asking for data from it
while (items.next())
	writeDump(items.curr());
	
// find only items with rating above 3 without hitting database again
favoriteItems = images.qoq().where("rating > ?", [3]).query();

// grab item with id of 56
item = items.findByKey(56);
</pre>
<p>See the docs on the <a href="https://github.com/dhumphreys/cfrel">GitHub page</a> for more information.</p>