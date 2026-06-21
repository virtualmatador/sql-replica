#include <sstream>
#include <string>

#include <json.hpp>
#include <schema.h>

#include "test_util.h"

bool t01() {
  auto tables = read_json("[]");
  auto functions = read_json("[]");
  auto procedures = read_json(R"([
    {
      "name": "set_value",
      "characteristics": ["MODIFIES SQL DATA", "SQL SECURITY INVOKER"],
      "params": [
        {"mode": "IN", "name": "input_value", "type": "int"},
        {"mode": "OUT", "name": "output_value", "type": "int"}
      ],
      "body": "SET output_value = input_value;"
    }
  ])");
  auto users = read_json("[]");
  const auto sql =
      Schema(schema(tables, functions, procedures, users), true, true).replicate_sql();
  return expect_contains(sql,
                         "set @_sql_tables = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(
             sql, "set @_sql_routines = if(isnull(@old_db), json_array()",
             __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_routines", __FUNCTION__) &&
         expect_contains(sql,
                         "set @procedure_delimiter = concat('d', "
                         "left(replace(uuid(), '-', ''), 13));",
                         __FUNCTION__) &&
         expect_contains(sql, "DROP PROCEDURE IF EXISTS `demo`.`set_value`;",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "CREATE PROCEDURE `demo`.`set_value`(IN `input_value` "
                         "int, OUT `output_value` int)",
                         __FUNCTION__) &&
         expect_contains(sql, "where not (`type` = 'PROCEDURE' and",
                         __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_routines",
                         __FUNCTION__) &&
         expect_not_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

bool t02() {
  auto tables = read_json("[]");
  auto functions = read_json("[]");
  auto procedures = read_json(R"([
    {
      "name": "set_value",
      "characteristics": ["MODIFIES SQL DATA", "SQL SECURITY INVOKER"],
      "params": [
        {"mode": "IN", "name": "input_value", "type": "int"},
        {"mode": "OUT", "name": "output_value", "type": "int"}
      ],
      "body": "SET output_value = input_value;"
    }
  ])");
  auto users = read_json("[]");
  const auto sql =
      Schema(schema(tables, functions, procedures, users), true, false).replicate_sql();
  return expect_contains(sql,
                         "set @_sql_tables = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(
             sql, "set @_sql_routines = if(isnull(@old_db), json_array()",
             __FUNCTION__) &&
         expect_contains(sql, "from json_table(@_sql_routines", __FUNCTION__) &&
         expect_contains(sql, "DROP PROCEDURE IF EXISTS `demo`.`set_value`;",
                         __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_routines",
                         __FUNCTION__) &&
         expect_contains(sql, "DELIMITER ', @procedure_delimiter",
                         __FUNCTION__) &&
         expect_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

int main() {
  if (t01() && t02() && true) {
    return 0;
  }
  return -1;
}
