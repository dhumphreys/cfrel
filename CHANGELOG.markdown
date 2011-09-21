# CFRel Changelog

## 0.1.2 - Bug Fixes

* Fixed column mappings for sql BETWEEN operations [Don]
* Fixed broken `afterFind` logic for wheels rels with no model [Don]

## 0.1.1 - Bug Fixes

* Allow model instances to be created from QoQ relations [Don]
* Allow ```findAll``` to use ```returnAs="relation"``` with any query [Don]

## 0.1 - First Release

* Object-oriented components for building complex SELECT queries [Don]
  * Chained syntax that allows high-level query decisions
  * Can return queries, result data, structures, and model objects
  * Relations can be cloned and sub-queried
* Recursive decent SQL parser for breaking input strings into tokens [Don]
  * Reads tokens into deep tree structures
  * Identifies columns in SQL that belong to models
  * Matches up ```?``` parameters to SQL datatypes of their columns
  * Unsupported strings can be passed in as _literals_
* Multiple visitors for generating SQL from tree structures [Don]
  * MySql
  * Sql Server
  * PostgreSql
  * Query-of-Queries
  * Generic Sql
* Plugin for cfwheels [Don]
  * Compatible with versions 1.1 - 1.1.5
  * Extends model query functionality
  * Supports associations and ```include``` parameters
  * Supports ```foreignKey``` and ```joinKey``` parameters
