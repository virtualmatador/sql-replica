#include <iostream>
#include <sstream>
#include <string>

#include <json.hpp>
#include <sqlr.h>

jsonio::json read_json(const std::string &text) {
  jsonio::json json;
  std::istringstream{text} >> json;
  return json;
}

bool t01() {
  auto tables = read_json("[]");
  auto functions = read_json("[]");
  auto procedures = read_json(R"([
    {
      "name": "bad_mode",
      "characteristics": [],
      "params": [
        {"mode": "BAD", "name": "input_value", "type": "int"}
      ],
      "body": "SET input_value = input_value;"
    }
  ])");
  auto users = read_json("[]");

  try {
    replicate_sql("demo", tables, functions, procedures, users, true, true);
  } catch (const std::runtime_error &e) {
    if (std::string{e.what()} == "Publish MySQL: Bad Procedure Param Mode") {
      return true;
    }
  }

  std::cerr << __FUNCTION__ << std::endl;
  return false;
}

int main() {
  if (t01() && true) {
    return 0;
  }
  return -1;
}
