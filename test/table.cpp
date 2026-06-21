#include <string>

#include <sqlr.h>

#include "test_util.h"

bool t01() {
  auto tables = read_json(R"([
    {
      "name": "account",
      "id": "ACCOUNT_TABLE",
      "columns": [
        {"id": "ACCOUNT_ID", "name": "id", "type": "int unsigned", "auto": true}
      ]
    }
  ])");
  auto empty = read_json("[]");
  const auto sql = replicate_sql("demo", tables, empty, empty, empty, false, true);
  return expect_sql(sql, read_file("table.sql"), __FUNCTION__);
}

int main() {
  if (t01() && true) {
    return 0;
  }
  return -1;
}
