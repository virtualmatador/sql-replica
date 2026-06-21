#include <iostream>
#include <sstream>
#include <string>

#include <json.hpp>
#include <schema.h>

jsonio::json read_json(const std::string &text) {
  jsonio::json json;
  std::istringstream{text} >> json;
  return json;
}

jsonio::json schema(const jsonio::json &tables, const jsonio::json &functions,
                    const jsonio::json &procedures, const jsonio::json &users) {
  jsonio::json result = jsonio::json_obj{};
  auto &object = result.get_object();
  object["name"] = "demo";
  object["tables"] = tables;
  object["functions"] = functions;
  object["procedures"] = procedures;
  object["users"] = users;
  return result;
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
    Schema(schema(tables, functions, procedures, users), true, true).replicate_sql();
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
