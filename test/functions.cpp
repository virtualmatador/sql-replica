#include <sstream>
#include <string>

#include <json.hpp>
#include <sqlr.h>

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
      replicate_sql("demo", tables, functions, procedures, users, true, true);
  return expect_sql(sql, read_file("functions.sql"), __FUNCTION__);
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
      replicate_sql("demo", tables, functions, procedures, users, true, false);
  return expect_sql(sql, read_file("functions-apply.sql"), __FUNCTION__);
}

int main() {
  if (t01() && t02() && true) {
    return 0;
  }
  return -1;
}
