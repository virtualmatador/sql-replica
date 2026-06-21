#include <functional>
#include <iostream>
#include <string>

#include <sqlr.h>

#include "test_util.h"

bool expect_throw(const std::function<void()> &fn, const char *test) {
  try {
    fn();
  } catch (const std::runtime_error &) {
    return true;
  }
  std::cerr << test << std::endl;
  return false;
}

bool t01_bad_db_name() {
  auto empty = read_json("[]");
  return expect_throw([&] {
    replicate_sql("demo\\", empty, empty, empty, empty, true, true);
  }, __FUNCTION__);
}

bool t02_bad_engine() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "engine": "InnoDB; DROP TABLE account",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ]
    }
  ])");
  auto empty = read_json("[]");
  return expect_throw([&] {
    replicate_sql("demo", tables, empty, empty, empty, true, true);
  }, __FUNCTION__);
}

bool t03_bad_key_type() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ],
      "keys": [
        {"name": "idx_account", "type": "index; DROP TABLE account", "columns": ["id"]}
      ]
    }
  ])");
  auto empty = read_json("[]");
  return expect_throw([&] {
    replicate_sql("demo", tables, empty, empty, empty, true, true);
  }, __FUNCTION__);
}

bool t04_bad_foreign_key_action() {
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
          "delete": "RESTRICT; DROP TABLE account",
          "update": "RESTRICT",
          "columns": ["id"],
          "table": "account",
          "keys": ["id"]
        }
      ]
    }
  ])");
  auto empty = read_json("[]");
  return expect_throw([&] {
    replicate_sql("demo", tables, empty, empty, empty, true, true);
  }, __FUNCTION__);
}

bool t05_bad_row_column() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ],
      "rows": [
        {"id`": "1"}
      ]
    }
  ])");
  auto empty = read_json("[]");
  return expect_throw([&] {
    replicate_sql("demo", tables, empty, empty, empty, true, true);
  }, __FUNCTION__);
}

bool t06_bad_user_subject() {
  auto empty = read_json("[]");
  auto users = read_json(R"([
    {
      "name": "Alice",
      "permissions": [
        {"type": "table", "subject": "account`", "operations": ["SELECT"]}
      ]
    }
  ])");
  return expect_throw([&] {
    replicate_sql("demo", empty, empty, empty, users, true, true);
  }, __FUNCTION__);
}

bool t07_bad_permission_type() {
  auto empty = read_json("[]");
  auto users = read_json(R"([
    {
      "name": "Alice",
      "permissions": [
        {"type": "trigger", "subject": "account", "operations": ["SELECT"]}
      ]
    }
  ])");
  return expect_throw([&] {
    replicate_sql("demo", empty, empty, empty, users, true, true);
  }, __FUNCTION__);
}

int main() {
  if (t01_bad_db_name() && t02_bad_engine() && t03_bad_key_type() &&
      t04_bad_foreign_key_action() && t05_bad_row_column() &&
      t06_bad_user_subject() && t07_bad_permission_type() && true) {
    return 0;
  }
  return -1;
}
