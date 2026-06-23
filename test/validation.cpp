#include <functional>
#include <iostream>
#include <string>

#include <schema.h>

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
  return expect_throw(
      [&] {
        Schema(schema("demo\\", empty, empty, empty), true, true).replicate_sql();
      },
      __FUNCTION__);
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
  return expect_throw(
      [&] { Schema(schema(tables, empty, empty), true, true).replicate_sql(); },
      __FUNCTION__);
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
  return expect_throw(
      [&] { Schema(schema(tables, empty, empty), true, true).replicate_sql(); },
      __FUNCTION__);
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
  return expect_throw(
      [&] { Schema(schema(tables, empty, empty), true, true).replicate_sql(); },
      __FUNCTION__);
}

bool t05_unknown_table_field() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned"}
      ],
      "extra": true
    }
  ])");
  auto empty = read_json("[]");
  return expect_throw(
      [&] { Schema(schema(tables, empty, empty), true, true).replicate_sql(); },
      __FUNCTION__);
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
  return expect_throw(
      [&] { Schema(schema(empty, empty, users), true, true).replicate_sql(); },
      __FUNCTION__);
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
  return expect_throw(
      [&] { Schema(schema(empty, empty, users), true, true).replicate_sql(); },
      __FUNCTION__);
}

bool t08_bad_routine() {
  auto empty = read_json("[]");
  auto routines = read_json(R"([
    "CREATE TRIGGER bad_trigger BEGIN END"
  ])");
  return expect_throw(
      [&] { Schema(schema(empty, routines, empty), true, true).replicate_sql(); },
      __FUNCTION__);
}

bool t09_bad_routine_schema() {
  auto empty = read_json("[]");
  auto routines = read_json(R"([
    "CREATE PROCEDURE other_db.set_value() BEGIN SELECT 1; END"
  ])");
  return expect_throw(
      [&] { Schema(schema(empty, routines, empty), true, true).replicate_sql(); },
      __FUNCTION__);
}

bool t10_bad_view_schema() {
  auto empty = read_json("[]");
  auto views = read_json(R"([
    "CREATE OR REPLACE VIEW other_db.account_view AS SELECT 1"
  ])");
  return expect_throw(
      [&] {
        Schema(schema("demo", empty, views, empty, empty), true, true)
            .replicate_sql();
      },
      __FUNCTION__);
}

bool t11_skip_comments() {
  auto empty = read_json("[]");
  auto routines = read_json(R"([
    "/* FUNCTION wrong_name */ CREATE PROCEDURE set_value() BEGIN SELECT 1; END"
  ])");
  auto views = read_json(R"([
    "-- VIEW wrong_name\nCREATE OR REPLACE VIEW account_view AS SELECT 1"
  ])");

  const auto routine_sql =
      Schema(schema(empty, routines, empty), true, true).replicate_sql();
  const auto view_sql =
      Schema(schema("demo", empty, views, empty, empty), true, true)
          .replicate_sql();

  return expect_contains(routine_sql,
                         "CREATE PROCEDURE `demo`.`set_value`()",
                         __FUNCTION__) &&
         expect_contains(view_sql,
                         "CREATE OR REPLACE VIEW `demo`.`account_view`",
                         __FUNCTION__);
}

int main() {
  if (t01_bad_db_name() && t02_bad_engine() && t03_bad_key_type() &&
      t04_bad_foreign_key_action() && t05_unknown_table_field() &&
      t06_bad_user_subject() && t07_bad_permission_type() &&
      t08_bad_routine() && t09_bad_routine_schema() &&
      t10_bad_view_schema() && t11_skip_comments() && true) {
    return 0;
  }
  return -1;
}
