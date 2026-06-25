# SQL Replication

"Sqlr" is a tool to maintain database schema.

The benefits of using "Sqlr":
- Uses structured input for tables without requiring hand-written table DDL
- Generates code without accessing the database server
- Doesn't require maintaining any kind of history

How the magic happens:
- Each table and column definition needs a GUID that shouldn't be changed through out the whole life of the project.

# Input

`Schema` receives one JSON schema object. The object contains the database name
and optional schema sections, and `Schema::replicate_sql()` generates the SQL.

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The database/schema name |
| tables | No | array or null | The array of table objects |
| views | No | array or null | The array of view objects |
| routines | No | array or null | The array of routine objects |
| users | No | array or null | The array of user objects |

Example:
```json
{
  "name": "demo",
  "tables": null,
  "views": null,
  "routines": null,
  "users": null
}
```

Optional section behavior is intentional and consistent:

- An omitted section or a section set to `null` is ignored.
- A section set to `[]` is reconciled as empty, so existing database objects for
  that section may be removed. The `users` section is different: MySQL accounts
  are server-level objects, so empty users removes database permissions for
  users with grants on this database; it does not drop user accounts.

The report flag and dry-run flag are still separate function arguments.

## Tables

The `tables` section is an array of table objects.

Example:
```json
[
]
```

### Table

A table is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| id | Yes | string | A GUID generated solely for this table |
| name | Yes | string | The name of the table |
| engine | No | string | The engine of the table |
| columns | Yes | array | The array of the column objects |
| keys | No | array | The array of the key objects |
| foreign-keys | No | array | The array of the foreign-key objects |

Example:
```json
{
    "name": "user",
    "id": "93B099B08D144B40BCC918FA24831669",
    "engine": "InnoDB",
    "columns": [
    ],
    "keys": [
    ],
    "foreign-keys": [
    ]
}
```

#### Column

A column is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| id | Yes | string | A GUID generated solely for this column |
| name | Yes | string | The name of the column |
| type | Yes | string | The type of the column |
| auto | No | boolean | The column is auto generated or no |
| null | No | boolean | The column accepts null values or no |
| default | No | string | The default value for the column |

Example:
```json
{
    "id": "76AC03C95026487AB55A590C48FE4C8F",
    "name": "id",
    "type": "int unsigned",
    "auto": true,
    "null": false,
    "default": ""
}
```

#### Key

A key is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The name of the key |
| type | Yes | string | The type of the key |
| columns | Yes | array | The name of the columns of the key |

Example:
```json
{
    "name": "PRIMARY",
    "type": "primary key",
    "columns": [
        "id"
    ]
}
```

#### Foreign Key

A foreign key is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The name of the foreign key |
| delete | Yes | string | The delete option of the foreign key |
| update | Yes | string | The update option of the foreign key |
| columns | Yes | array | The name of the columns of the key |
| table | Yes | string | The name of the foreign table |
| keys | Yes | array | The name of columns in the foreign table |

Example:
```json
{
    "name": "fk_member_user",
    "delete": "RESTRICT",
    "update": "RESTRICT",
    "columns": [
        "user"
    ],
    "table": "user",
    "keys": [
        "id"
    ]
}
```

## Views (optional)

The `views` section is an array of MySQL view definitions. Sqlr expects each
view to provide its name and body only.

Example:
```json
[
]
```

### View

A view is an object containing the view `name` and the SQL `body` after `AS`.
Put the `SELECT` command in `body` without a trailing semicolon. Sqlr adds
`CREATE OR REPLACE VIEW`, qualifies the view name with the target
database/schema, appends `AS`, and terminates the generated view statement with
a semicolon.

Example:
```json
[
    {
        "name": "project_account",
        "body": "SELECT `project`.`id`, `project`.`name` FROM `project`"
    }
]
```

## Routines (optional)

The `routines` section is an array of MySQL function and procedure definitions.
Sqlr expects each routine to provide its type, name, and the rest of its
definition after the name.

Example:
```json
[
]
```

### Routine

A routine is an object containing `type`, `name`, and `definition`. `type` must
be `FUNCTION` or `PROCEDURE`. `definition` starts immediately after the routine
name, usually with the parameter list. Sqlr adds the `CREATE FUNCTION` or
`CREATE PROCEDURE` prefix and qualifies the name with the target
database/schema while generating SQL.

Example:
```json
[
    {
        "type": "FUNCTION",
        "name": "double_value",
        "definition": "(`input_value` int) RETURNS int DETERMINISTIC NO SQL BEGIN RETURN input_value * 2; END"
    }
]
```

```json
[
    {
        "type": "PROCEDURE",
        "name": "set_value",
        "definition": "(IN `input_value` int, OUT `output_value` int) MODIFIES SQL DATA BEGIN SET output_value = input_value; END"
    }
]
```

## Users (optional)

The `users` section is an array of user objects. User accounts are server-level
objects, not database objects, so sqlr never drops MySQL users. Declared users
are created if missing, and their permissions for this database are reconciled.
Users omitted from this section keep their accounts, but their permissions on
this database are removed.

Example:
```json
[
]
```

### User

A user is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The username |
| permissions | Yes | array | The array of the permission objects |

Example:
```json
{
  "name": "Alice",
  "permissions": [
  ]
}
```

#### Permission

A permission is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| type | Yes | string | The type of subject: `table`, `function`, or `procedure` |
| subject | Yes | string | The name of the table/view, function, or procedure |
| operations | Yes | array | The array of the operations that user is allowed to do on the subject |

Example permission for table:
```json
{
  "type": "table",
  "subject": "user",
  "operations": [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE"
  ]
}
```

Example permission for function:
```json
{
  "type": "function",
  "subject": "active_user_count",
  "operations": [
    "EXECUTE"
  ]
}
```

# Output

The output is a SQL code that will apply required changes in a server.

# Remarks

- The GUID of the tables and columns shouldn't be changed through out the lifetime of the project. Changing them will cause data loss.
- New user accounts are locked to prevent unwanted access. After applying the output, admins need to alter new users to set a password and unlock the account. e.g. ALTER USER 'Alice' IDENTIFIED BY "${password_for_alice}" ACCOUNT UNLOCK;
- User accounts are not dropped by sqlr. Remove or lock accounts outside sqlr when a server-level account is no longer needed. To remove a user's access to this database, omit the user from the `users` section or set `users` to `[]`.

# Application

SQL Replica is a command-line application that wraps the `sqlr` library. It
generates MySQL schema synchronization SQL from declarative JSON files.

The application reads table, view, stored routine, user, and permission
definitions, compares them against MySQL metadata at execution time, and emits
SQL that updates a database to match those definitions.

Project page: https://www.shaidin.com/sql-sync

## Build

From the repository root:

```sh
cmake -S . -B build
cmake --build build
```

The binary is created at:

```sh
build/sql-replica
```

Run tests with:

```sh
ctest --test-dir build --output-on-failure
```

Build a Debian package with:

```sh
cmake --build build --target package
```

## Usage

```sh
sql-replica [options] < schema.json
```

Options:

```text
-v, --version              Print version.
-i, --input-file <file>    Read the schema JSON object from a file instead of
                           standard input.
-o, --output-file <file>   Write generated SQL to a file instead of stdout.
-r, --report               Include command-reporting output in generated SQL.
-d, --dry-run              Generate SQL that reports required changes without
                           executing them.
```

Example:

```sh
build/sql-replica \
  --report \
  --dry-run \
  --input-file schema.json \
  --output-file sql.sql
```

## Application Output

By default, SQL Replica emits executable MySQL SQL. Each generated statement is
stored in `@qry`, prepared, executed, and deallocated.

With `--dry-run`, generated SQL reports the commands it would run without
executing them. With `--report`, generated SQL also emits each command for
visibility.

## Repository Layout

```text
main.cpp          CLI entry point.
extern/jsonio     JSON support library.
extern/cli        CLI argument parser.
```
