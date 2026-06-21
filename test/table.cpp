#include <string>

#include <schema.h>

#include "test_util.h"

bool t01() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned", "auto": true}
      ]
    }
  ])");
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(tables, empty, empty, empty), false, true).replicate_sql();
  return expect_contains(sql,
                         "set @_sql_tables = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "set @_sql_columns = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_tables", __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_columns", __FUNCTION__) &&
         expect_contains(sql, "'CREATE TABLE `demo`.`_sql_account`",
                         __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_tables", __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_columns",
                         __FUNCTION__) &&
         expect_contains(sql, "json_set(@_sql_columns", __FUNCTION__) &&
         expect_contains(
             sql, "order by `TABLE_NAME`, `ORDINAL_POSITION`, `COLUMN_NAME`",
             __FUNCTION__) &&
         expect_not_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

bool t02_rename_updates_dependents() {
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
  const auto sql =
      Schema(schema(tables, empty, empty, empty), false, true).replicate_sql();
  return expect_contains(
             sql,
             "set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes",
             __FUNCTION__) &&
         expect_contains(
             sql, "'table', if(`table` = @old_table, @new_table, `table`)",
             __FUNCTION__) &&
         expect_contains(sql,
                         "set @_sql_foreign_keys = if(@new_table = @old_table, "
                         "@_sql_foreign_keys",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "'referenced_table', if(`referenced_table` = "
                         "@old_table, @new_table, `referenced_table`)",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "replace(`key_def`, concat('`', @old_column, '`'), "
                         "concat('`', @new_column, '`'))",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "replace(`f_key_def`, concat('`', @old_column, '`'), "
                         "concat('`', @new_column, '`'))",
                         __FUNCTION__);
}

int main() {
  if (t01() && t02_rename_updates_dependents() && true) {
    return 0;
  }
  return -1;
}
