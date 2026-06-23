#include <string>

#include <schema.h>

#include "test_util.h"

bool t01() {
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(empty, empty, empty), true, true).replicate_sql();
  return expect_contains(sql,
                         "set @_sql_tables = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "set @_sql_columns = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(sql,
                         "set @_sql_indexes = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(
             sql, "set @_sql_foreign_keys = if(isnull(@old_db), json_array()",
             __FUNCTION__) &&
         expect_contains(sql,
                         "set @_sql_views = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(sql, "set @_sql_users =", __FUNCTION__) &&
         expect_contains(sql, "set @_sql_permissions =", __FUNCTION__) &&
         expect_contains(sql, "set @all_users = '';", __FUNCTION__) &&
         expect_not_contains(sql, "DROP USER", __FUNCTION__) &&
         expect_contains(sql, "select @qry as '';", __FUNCTION__) &&
         expect_not_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

bool t02() {
  auto empty = read_json("[]");
  const auto sql =
      Schema(schema(empty, empty, empty), true, false).replicate_sql();
  return expect_contains(sql,
                         "set @_sql_tables = if(isnull(@old_db), json_array()",
                         __FUNCTION__) &&
         expect_contains(sql, "select @qry as '';", __FUNCTION__) &&
         expect_contains(sql, "prepare stmt from @qry;", __FUNCTION__);
}

bool t03_null_sections_skip_work() {
  auto null = read_json("null");
  const auto null_sql =
      Schema(schema(null, null, null), true, true).replicate_sql();
  const auto omitted_sql =
      Schema(read_json(R"({"name":"demo"})"), true, true).replicate_sql();
  return expect_not_contains(null_sql, "set @_sql_tables =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @_sql_columns =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @_sql_indexes =", __FUNCTION__) &&
         expect_not_contains(null_sql,
                             "set @_sql_foreign_keys =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @_sql_views =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @_sql_routines =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @_sql_users =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @all_tables =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @all_routines =", __FUNCTION__) &&
         expect_not_contains(null_sql, "set @all_users =", __FUNCTION__) &&
         expect_not_contains(omitted_sql, "set @_sql_tables =", __FUNCTION__) &&
         expect_not_contains(omitted_sql,
                             "set @_sql_routines =", __FUNCTION__) &&
         expect_not_contains(omitted_sql, "set @_sql_users =", __FUNCTION__);
}

bool t04_empty_sections_reconcile_work() {
  auto empty = read_json("[]");
  auto null = read_json("null");

  const auto table_sql =
      Schema(schema(empty, null, null), true, true).replicate_sql();
  const auto routine_sql =
      Schema(schema(null, empty, null), true, true).replicate_sql();
  const auto user_sql =
      Schema(schema(null, null, empty), true, true).replicate_sql();

  return expect_contains(table_sql, "set @all_tables = '';", __FUNCTION__) &&
         expect_contains(table_sql, "DROP TABLE", __FUNCTION__) &&
         expect_not_contains(table_sql, "set @all_routines = '';",
                             __FUNCTION__) &&
         expect_contains(routine_sql, "set @all_routines = '';",
                         __FUNCTION__) &&
         expect_contains(routine_sql, "DROP ', `type`, ' `demo`.`",
                         __FUNCTION__) &&
         expect_not_contains(routine_sql, "set @all_tables = '';",
                             __FUNCTION__) &&
         expect_contains(user_sql, "set @all_users = '';", __FUNCTION__) &&
         expect_contains(user_sql, "No unlisted user permissions.",
                         __FUNCTION__) &&
         expect_contains(user_sql,
                         "REVOKE ', `operations`, ' ON `demo`.`",
                         __FUNCTION__) &&
         expect_contains(user_sql,
                         "REVOKE ', `operations`, ' ON ', `type`, ' `demo`.`",
                         __FUNCTION__) &&
         expect_not_contains(user_sql, "DROP USER", __FUNCTION__) &&
         expect_not_contains(user_sql, "set @all_tables = '';", __FUNCTION__);
}

int main() {
  if (t01() && t02() && t03_null_sections_skip_work() &&
      t04_empty_sections_reconcile_work() && true) {
    return 0;
  }
  return -1;
}
