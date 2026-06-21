#include <iostream>
#include <string>

#include <schema.h>

#include "test_util.h"

bool t01() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ],
      "keys": [
        {"name": "idx_account", "type": "index", "columns": ["id"]}
      ],
      "foreign-keys": [
        {
          "name": "fk_account",
          "delete": "RESTRICT",
          "update": "RESTRICT",
          "columns": ["id"],
          "table": "account",
          "keys": ["id"]
        }
      ]
    }
  ])");
  auto empty = read_json("[]");
  auto users = read_json(R"([
    {
      "name": "Alice",
      "permissions": [
        {"type": "table", "subject": "account", "operations": ["SELECT"]},
        {"type": "function", "subject": "double_value", "operations": ["EXECUTE"]},
        {"type": "procedure", "subject": "set_value", "operations": ["EXECUTE"]}
      ]
    }
  ])");
  const auto sql =
      Schema(schema(tables, empty, empty, users), false, true).replicate_sql();
  return expect_contains(sql,
                         "set @all_foreign_keys = concat(@all_foreign_keys, "
                         "'{fk_account}');",
                         __FUNCTION__) &&
         expect_contains(sql, "set @_sql_users =", __FUNCTION__) &&
         expect_contains(sql, "from `mysql`.`user`", __FUNCTION__) &&
         expect_contains(sql, "from `mysql`.`tables_priv`", __FUNCTION__) &&
         expect_contains(sql, "from `mysql`.`procs_priv`", __FUNCTION__) &&
         expect_contains(sql, "where `Db` = 'demo'", __FUNCTION__) &&
         expect_not_contains(sql, "DROP USER", __FUNCTION__) &&
         expect_contains(sql, "set @_sql_permissions =", __FUNCTION__) &&
         expect_contains(sql,
                         "set @all_users = concat(@all_users, '{Alice}');",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "instr(@all_users, concat('{', `user`, '}')) = 0",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "REVOKE IF EXISTS SELECT, INSERT, UPDATE, DELETE, "
                         "EXECUTE ON `demo`.* FROM ",
                         __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_foreign_keys",
                         __FUNCTION__) &&
         expect_contains(
             sql, "instr(@all_foreign_keys, concat('{', `name`, '}')) = 0",
             __FUNCTION__) &&
         expect_contains(
             sql,
             "where not (`table` = @old_table and `name` = @old_constraint)",
             __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_foreign_keys",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "set @all_keys = concat(@all_keys, '{idx_account}');",
                         __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_indexes", __FUNCTION__) &&
         expect_contains(sql, "instr(@all_keys, concat('{', `name`, '}')) = 0",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "where `table` != 'account' or `foreign_key` = true",
                         __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_indexes",
                         __FUNCTION__) &&
         expect_contains(
             sql, "set @all_grants = concat(@all_grants, '{TABLE:account}');",
             __FUNCTION__) &&
         expect_contains(sql,
                         "set @all_grants = concat(@all_grants, "
                         "'{FUNCTION:double_value}');",
                         __FUNCTION__) &&
         expect_contains(
             sql,
             "set @all_grants = concat(@all_grants, '{PROCEDURE:set_value}');",
             __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_permissions",
                         __FUNCTION__) &&
         expect_contains(
             sql, "instr(@all_grants, concat('{TABLE:', `subject`, '}')) = 0",
             __FUNCTION__) &&
         expect_contains(
             sql,
             "instr(@all_grants, concat('{', `type`, ':', `subject`, '}')) = 0",
             __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_users", __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_permissions",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "GRANT Select ON `demo`.`account` TO \\'Alice\\';",
                         __FUNCTION__) &&
         expect_contains(
             sql,
             "GRANT Execute ON FUNCTION `demo`.`double_value` TO \\'Alice\\';",
             __FUNCTION__) &&
         expect_contains(
             sql,
             "GRANT Execute ON PROCEDURE `demo`.`set_value` TO \\'Alice\\';",
             __FUNCTION__);
}

int main() {
  if (t01() && true) {
    return 0;
  }
  return -1;
}
