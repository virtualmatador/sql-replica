#include <sstream>
#include <string>

#include <json.hpp>
#include <sqlr.h>

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
      replicate_sql("demo", tables, functions, procedures, users, true, true);
  return expect_sql(sql, read_file("procedures.sql"), __FUNCTION__);
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
      replicate_sql("demo", tables, functions, procedures, users, true, false);
  return expect_sql(sql, read_file("procedures-apply.sql"), __FUNCTION__);
}

int main() {
  if (t01() && t02() && true) {
    return 0;
  }
  return -1;
}
