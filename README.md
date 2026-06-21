# SQL Replication

"Sqlr" is a tool to maintain database schema.

The benefits of using "Sqlr":
- Uses the simplest form of the input without requiring SQL language
- Generates code without accessing the database server
- Doesn't require maintaining any kind of history

How the magic happens:
- Each table and column definition needs a GUID that shouldn't be changed through out the whole life of the project.

# Input

The following items are needed:
- database name
- tables definition json array file
- functions definition json array file, optional
- procedures definition json array file, optional
- users definition json array file, optional
- report flag to add informative logs to SQL output, optional
- dry-run flag to list required changes without applying them, optional

## Tables

The tables are defined by an array of the table objects.

Example:
```
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
| views | No | array | The array of the view objects |

Example:
```
{
    "name": "user",
    "id": "93B099B08D144B40BCC918FA24831669",
    "engine": "InnoDB",
    "columns": [
    ],
    "keys": [
    ],
    "foreign-keys": [
    ],
    "views": [
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
```
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
```
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
```
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

#### View

A view is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The name of the view |
| columns | Yes | array | The name of the columns joining the view |
| joints | Yes | array | The array of the joint objects, joins of the view |

Example:
```
{
    "name": "membership",
    "columns": [
        "id"
    ],
    "joints": [
    ]
}
```

##### Joint

A joint is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| table | Yes | string | The name of the table joining the view |
| as | Yes | string | The alias for the table to be used in the view |
| type | Yes | string | The type of the joint |
| columns | Yes | array | The name of the columns of the table joining the view |
| ons | Yes | array | The array of the relation objects, between this table and the rest of the view |

Example:
```
{
    "table": "project",
    "as": "prj",
    "type": "inner",
    "columns": [
      "id"
    ],
    "ons": [
    ]
}
```

###### Relation

A relation is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| foreign | Yes | string | The column used for comparison |
| base | Yes | object | The table and the column to compare with |

Example:
```
{
  "foreign": "project",
  "base": {
    "table": "project",
    "column": "id",
  }
}
```

## Functions (optional)

Functions are defined by a json array file.

Example:
```
[
]
```

### Function

A function is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The name of the function |
| returns | Yes | string | The function return type |
| characteristics | Yes | array | The array of function characteristics, such as `DETERMINISTIC` or `READS SQL DATA` |
| params | Yes | array | The array of the function parameter objects |
| body | Yes | string | The function body, without the top `BEGIN` and bottom `END` |

Example:
```
{
    "name": "double_value",
    "returns": "int",
    "characteristics": ["DETERMINISTIC", "READS SQL DATA"],
    "params": [
        {
            "name": "input_value",
            "type": "int"
        }
    ],
    "body": "RETURN input_value * 2;"
}
```

#### Function Parameter

A function parameter is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The name of the parameter |
| type | Yes | string | The type of the parameter |

## Procedures (optional)

Procedures are defined by a json array file.

Example:
```
[
]
```

### Procedure

A procedure is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| name | Yes | string | The name of the procedure |
| characteristics | Yes | array | The array of procedure characteristics, such as `MODIFIES SQL DATA` or `SQL SECURITY INVOKER` |
| params | Yes | array | The array of the procedure parameter objects |
| body | Yes | string | The procedure body, without the top `BEGIN` and bottom `END` |

Example:
```
{
    "name": "set_value",
    "characteristics": ["MODIFIES SQL DATA", "SQL SECURITY INVOKER"],
    "params": [
        {
            "mode": "IN",
            "name": "input_value",
            "type": "int"
        },
        {
            "mode": "OUT",
            "name": "output_value",
            "type": "int"
        }
    ],
    "body": "SET output_value = input_value;"
}
```

#### Procedure Parameter

A procedure parameter is an object that has the following fields:

| Field Name | Required | Type | Description |
| --- | --- | --- | --- |
| mode | Yes | string | The parameter mode, `IN`, `OUT`, or `INOUT` |
| name | Yes | string | The name of the parameter |
| type | Yes | string | The type of the parameter |

## Users (optional)

The users are defined by an array of the user objects.

Example:
```
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
```
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
| subject | Yes | string | The name of the table, function, or procedure |
| operations | Yes | array | The array of the operations that user is allowed to do on the subject |

Example permission for table:
```
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
```
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
- The account of the new users are locked to prevent unwanted access. After applying the output, admins need to alter new users to set password and unlock the accoutn. e.g. ALTER USER 'Alice' IDENTIFIED BY "${password_for_alice}" ACCOUNT UNLOCK;
