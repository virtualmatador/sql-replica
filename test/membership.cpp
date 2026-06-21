#include <iostream>
#include <string>

#include <sqlr.h>

#include "test_util.h"

bool contains(const std::string &text, const std::string &needle) {
  return text.find(needle) != std::string::npos;
}

bool expect_contains(const std::string &text, const std::string &needle,
                     const char *test) {
  if (contains(text, needle)) {
    return true;
  }
  std::cerr << test << ": missing " << needle << std::endl;
  return false;
}

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
  const auto sql = replicate_sql("demo", tables, empty, empty, users, false, true);
  return expect_contains(sql, "set @all_foreign_keys = concat(@all_foreign_keys, '{fk_account}');", __FUNCTION__) &&
         expect_contains(sql, "`CONSTRAINT_SCHEMA` = 'demo' and\n    `CONSTRAINT_NAME` = 'fk_account'", __FUNCTION__) &&
         expect_contains(sql, "instr(@all_foreign_keys, concat('{', `CONSTRAINT_NAME`, '}')) = 0", __FUNCTION__) &&
         expect_contains(sql, "`TABLE_SCHEMA` = 'demo' and\n    `TABLE_NAME` = 'account' and\n    `CONSTRAINT_NAME` = 'fk_account'", __FUNCTION__) &&
         expect_contains(sql, "group by `CONSTRAINT_NAME`, `TABLE_NAME`;", __FUNCTION__) &&
         expect_contains(sql, "set @all_keys = concat(@all_keys, '{idx_account}');", __FUNCTION__) &&
         expect_contains(sql, "instr(@all_keys, concat('{', `INDEX_NAME`, '}')) = 0", __FUNCTION__) &&
         expect_contains(sql, "set @all_grants = concat(@all_grants, '{TABLE:account}');", __FUNCTION__) &&
         expect_contains(sql, "set @all_grants = concat(@all_grants, '{FUNCTION:double_value}');", __FUNCTION__) &&
         expect_contains(sql, "set @all_grants = concat(@all_grants, '{PROCEDURE:set_value}');", __FUNCTION__) &&
         expect_contains(sql, "instr(@all_grants, concat('{TABLE:', `table_name`, '}')) = 0", __FUNCTION__) &&
         expect_contains(sql, "instr(@all_grants, concat('{', `routine_type`, ':', `routine_name`, '}')) = 0", __FUNCTION__) &&
         expect_contains(sql, "GRANT Select ON `demo`.`account` TO \\'Alice\\';", __FUNCTION__) &&
         expect_contains(sql, "GRANT Execute ON FUNCTION `demo`.`double_value` TO \\'Alice\\';", __FUNCTION__) &&
         expect_contains(sql, "GRANT Execute ON PROCEDURE `demo`.`set_value` TO \\'Alice\\';", __FUNCTION__);
}

int main() {
  if (t01() && true) {
    return 0;
  }
  return -1;
}
