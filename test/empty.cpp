#include <string>

#include <sqlr.h>

#include "test_util.h"

bool t01() {
  auto empty = read_json("[]");
  const auto sql = replicate_sql("demo", empty, empty, empty, empty, true, true);
  return expect_sql(sql, read_file("empty.sql"), __FUNCTION__);
}

bool t02() {
  auto empty = read_json("[]");
  const auto sql =
      replicate_sql("demo", empty, empty, empty, empty, true, false);
  return expect_sql(sql, read_file("empty-apply.sql"), __FUNCTION__);
}

int main() {
  if (t01() && t02() && true) {
    return 0;
  }
  return -1;
}
