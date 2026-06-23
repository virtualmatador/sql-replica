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
      Schema(schema(tables, empty, empty), false, true).replicate_sql();
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
         expect_contains(sql, "'name', '_sql_'", __FUNCTION__) &&
         expect_contains(sql, "DROP COLUMN `', `name`, '`'", __FUNCTION__) &&
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
      Schema(schema(tables, empty, empty), false, true).replicate_sql();
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

bool t03_keys_are_applied_before_state_update() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned", "auto": true}
      ],
      "keys": [
        {"name": "PRIMARY", "type": "primary key", "columns": ["id"]}
      ]
    }
  ])");
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(tables, empty, empty), false, false).replicate_sql();
  const auto check_index = sql.find("select\n  `name`,\n  `key_def`");
  const auto update_index = sql.find("json_array_append(@_sql_indexes");
  return check_index != std::string::npos &&
         update_index != std::string::npos && check_index < update_index &&
         expect_contains(sql, "ADD primary key (`id`),", __FUNCTION__) &&
         expect_contains(sql, "DROP PRIMARY KEY, ", __FUNCTION__) &&
         expect_not_contains(sql, "ADD primary key `PRIMARY`", __FUNCTION__) &&
         expect_not_contains(sql, "DROP INDEX `PRIMARY`", __FUNCTION__);
}

bool t04_dropped_foreign_key_releases_index_state() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
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
      Schema(schema(tables, empty, empty), false, false).replicate_sql();
  return expect_contains(
             sql,
             "if(`table` = @old_table and `name` = @old_constraint, false, "
             "`foreign_key`)",
             __FUNCTION__) &&
         expect_contains(
             sql,
             "if(`table` = 'account' and instr(@all_foreign_keys, concat('{', "
             "`name`, '}')) = 0",
             __FUNCTION__);
}

bool t05_marked_extra_tables_move_dependent_state() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ]
    }
  ])");
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(tables, empty, empty), false, false).replicate_sql();
  return expect_contains(
             sql,
             "`planned_tables`.`name` = `_sql_ordered_columns`.`table`",
             __FUNCTION__) &&
         expect_contains(
             sql,
             "`planned_tables`.`name` = `_sql_ordered_indexes`.`table`",
             __FUNCTION__) &&
         expect_contains(sql,
                         "`planned_tables`.`name` = "
                         "`_sql_ordered_foreign_keys`.`referenced_table`",
                         __FUNCTION__);
}

bool t06_extra_columns_stale_dependent_state() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ]
    }
  ])");
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(tables, empty, empty), false, false).replicate_sql();
  return expect_contains(sql, "concat('__stale__', `key_def`)",
                         __FUNCTION__) &&
         expect_contains(sql, "concat('__stale__', `f_key_def`)",
                         __FUNCTION__);
}

bool t07_default_drop_uses_state_before_clearing() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ]
    }
  ])");
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(tables, empty, empty), false, false).replicate_sql();
  const auto keep_default = sql.find("json_extract(@_sql_columns, "
                                     "concat(@column_object, '.default'))");
  const auto drop_default = sql.find("ALTER COLUMN `id` DROP DEFAULT");
  const auto clear_default = sql.find(
      "json_set(@_sql_columns, concat(@column_object, '.default'), null)",
      drop_default);
  return keep_default != std::string::npos &&
         drop_default != std::string::npos &&
         clear_default != std::string::npos && keep_default < drop_default &&
         drop_default < clear_default;
}

int main() {
  if (t01() && t02_rename_updates_dependents() &&
      t03_keys_are_applied_before_state_update() &&
      t04_dropped_foreign_key_releases_index_state() &&
      t05_marked_extra_tables_move_dependent_state() &&
      t06_extra_columns_stale_dependent_state() &&
      t07_default_drop_uses_state_before_clearing() && true) {
    return 0;
  }
  return -1;
}
