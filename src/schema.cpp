#include "schema.h"

#include "objects.h"
#include "routines.h"
#include "tables.h"
#include "users.h"
#include "views.h"

Schema::Schema(const jsonio::json &schema, bool report, bool dry_run)
    : schema_(schema), report_(report), dry_run_(dry_run) {}

std::string Schema::replicate_sql() const {
  const auto &db_name = schema_name();
  const auto &tables = section_or_null("tables");
  const auto &views = section_or_null("views");
  const auto &routines = section_or_null("routines");
  const auto &users = section_or_null("users");

  const bool include_tables = !Objects::is_null(tables);
  const bool include_views = !Objects::is_null(views);
  const bool include_routines = !Objects::is_null(routines);
  const bool include_users = !Objects::is_null(users);

  Context context{db_name, "_sql_", "_drop_", ""};
  Objects::sanitize(context.db_name, Objects::SanitizeRule::DatabaseName);

  if (include_tables) {
    Tables::validate(tables, context.bad_prefix);
  }
  if (include_views) {
    Views::validate(views);
  }
  if (include_routines) {
    Routines::validate(routines);
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
  if (report_) {
    sql += R"(
select 'USE `)" + context.db_name + R"(`;' as '';
)";
  }
  if (!dry_run_) {
    sql += R"(
USE `)" + context.db_name + R"(`;
)";
  }
  if (include_tables) {
    sql += Tables::snapshot_schema_state(context.db_name);
  }
  if (include_views) {
    sql += Views::snapshot_schema_state(context.db_name);
  }
  if (include_routines) {
    sql += Routines::snapshot_schema_state(context.db_name);
  }
  if (include_users) {
    sql += Users::snapshot_schema_state(context.db_name);
  }

  if (include_tables) {
    sql += Tables::generate(tables, context);
  }
  if (include_views) {
    sql += Views::generate(views, context);
  }
  if (include_routines) {
    sql += Routines::generate(routines, context);
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
