#include <sstream>
#include <string>

#include <json.hpp>
#include <schema.h>

#include "test_util.h"

bool t01() {
  auto tables = read_json("[]");
  auto functions = read_json(R"([
    {
      "name": "double_value",
      "returns": "int",
      "characteristics": ["DETERMINISTIC", "READS SQL DATA"],
      "params": [
        {"name": "input_value", "type": "int"}
      ],
      "body": "RETURN input_value * 2;"
    }
  ])");
  auto procedures = read_json("[]");
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
                         "set @function_delimiter = concat('d', "
                         "left(replace(uuid(), '-', ''), 13));",
                         __FUNCTION__) &&
         expect_contains(sql, "DROP FUNCTION IF EXISTS `demo`.`double_value`;",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "CREATE FUNCTION `demo`.`double_value`(`input_value` "
                         "int) RETURNS int DETERMINISTIC READS SQL DATA",
                         __FUNCTION__) &&
         expect_contains(sql, "where not (`type` = 'FUNCTION' and",
                         __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_routines",
                         __FUNCTION__) &&
         expect_not_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

bool t02() {
  auto tables = read_json("[]");
  auto functions = read_json(R"([
    {
      "name": "double_value",
      "returns": "int",
      "characteristics": ["DETERMINISTIC", "READS SQL DATA"],
      "params": [
        {"name": "input_value", "type": "int"}
      ],
      "body": "RETURN input_value * 2;"
    }
  ])");
  auto procedures = read_json("[]");
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
         expect_contains(sql, "DROP FUNCTION IF EXISTS `demo`.`double_value`;",
                         __FUNCTION__) &&
         expect_contains(sql, "json_array_append(@_sql_routines",
                         __FUNCTION__) &&
         expect_contains(sql, "DELIMITER ', @function_delimiter",
                         __FUNCTION__) &&
         expect_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

int main() {
  if (t01() && t02() && true) {
    return 0;
  }
  return -1;
}
