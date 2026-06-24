#include <fstream>
#include <stdexcept>
#include <string>

#include <schema.h>

#include "test_util.h"

namespace {

jsonio::json read_json_file(const std::string &name) {
  const auto path = std::string{SQLR_TEST_DIR} + "/" + name;
  std::ifstream stream{path};
  if (!stream) {
    throw std::runtime_error("Could not open " + path);
  }
  jsonio::json json;
  stream >> json;
  return json;
}

jsonio::json sql_sync_schema() {
  auto result = read_json_file("sql-sync/schema.json");
  auto &object = result.get_object();
  object["tables"] = read_json_file("sql-sync/tables.json");
  object["views"] = read_json_file("sql-sync/views.json");
  object["routines"] = read_json_file("sql-sync/routines.json");
  object["users"] = read_json_file("sql-sync/users.json");
  return result;
}

bool t01_generates_sql_sync_result() {
  const auto sql = Schema(sql_sync_schema(), true, true).replicate_sql();
  return expect_sql(sql, read_file("sql-sync/sql.sql"), __FUNCTION__);
}

bool t02_uses_new_view_and_routine_shapes() {
  const auto sql = Schema(sql_sync_schema(), true, true).replicate_sql();
  return expect_contains(
             sql,
             "CREATE OR REPLACE VIEW `sales`.`project_account` AS SELECT",
             __FUNCTION__) &&
         expect_contains(sql,
                         "CREATE FUNCTION `sales`.`active_project_count`()",
                         __FUNCTION__) &&
         expect_contains(
             sql,
             "CREATE PROCEDURE `sales`.`archive_project`(IN `project_id`",
             __FUNCTION__);
}

} // namespace

int main() {
  if (t01_generates_sql_sync_result() &&
      t02_uses_new_view_and_routine_shapes() && true) {
    return 0;
  }
  return -1;
}
