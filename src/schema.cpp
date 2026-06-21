#include "schema.h"

#include "functions.h"
#include "objects.h"
#include "routines.h"
#include "tables.h"
#include "users.h"

Schema::Schema(const jsonio::json &schema, bool report, bool dry_run)
    : schema_(schema), report_(report), dry_run_(dry_run) {}

std::string Schema::replicate_sql() const {
  const auto &db_name = schema_name();
  const auto &tables = section_or_null("tables");
  const auto &functions = section_or_null("functions");
  const auto &procedures = section_or_null("procedures");
  const auto &users = section_or_null("users");

  const bool include_tables = !Objects::is_null(tables);
  const bool include_functions = !Objects::is_null(functions);
  const bool include_procedures = !Objects::is_null(procedures);
  const bool include_users = !Objects::is_null(users);

  Context context{db_name, "_sql_", "_drop_", ""};
  Objects::sanitize(context.db_name, "\\'`");

  if (include_tables) {
    Tables::validate(tables, context.bad_prefix);
  }
  if (include_functions) {
    Functions::validate(functions);
  }
  if (include_procedures) {
    Routines::validate(procedures);
  }
  if (include_users) {
    Users::validate(users);
  }

  if (report_) {
    context.exec += R"(
select @qry as '';
)";
  }
  if (!dry_run_) {
    context.exec += R"(
prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;
)";
  }

  std::string sql;
  sql += R"(
set @old_db = null;
select `SCHEMA_NAME` into @old_db from `INFORMATION_SCHEMA`.`SCHEMATA`
where `SCHEMA_NAME` = ')" +
         context.db_name + R"(';
set @qry = if (isnull(@old_db),
    'CREATE DATABASE `)" +
         context.db_name + R"(`;'
,
    'SET @r = \'Database ")" +
         context.db_name + R"(" exists.\';'
);
  )";
  sql += context.exec;
  if (include_tables) {
    sql += Tables::snapshot_schema_state(context.db_name);
  }
  if (include_functions || include_procedures) {
    sql += Routines::snapshot_schema_state(context.db_name);
  }
  if (include_users) {
    sql += Users::snapshot_schema_state(context.db_name);
  }

  if (include_tables) {
    sql += Tables::generate(tables, context);
  }
  if (include_functions) {
    sql += Functions::generate(functions, context);
  }
  if (include_procedures) {
    sql += Routines::generate(procedures, context);
  }
  if (include_users) {
    sql += Users::generate(users, context);
  }

  return sql;
}

const jsonio::json_obj &Schema::schema_object() const {
  if (Objects::is_null(schema_) ||
      schema_.type() != jsonio::JsonType::J_OBJECT) {
    throw std::runtime_error("Publish MySQL: Schema must be object");
  }
  return schema_.get_object();
}

const std::string &Schema::schema_name() const {
  const auto &object = schema_object();
  if (const auto value = object.at("name");
      value && !Objects::is_null(*value)) {
    return value->get_string();
  }
  throw std::runtime_error("Publish MySQL: Schema name required");
}

const jsonio::json &Schema::section_or_null(const char *section) const {
  static const jsonio::json null;
  const auto &object = schema_object();
  if (const auto value = object.at(section); value) {
    return *value;
  }
  return null;
}
