#include "views.h"

#include "objects.h"

void Views::validate(const jsonio::json &views) {
  for (const auto &view : views.get_array()) {
    Objects::validate_fields(view, {"name", "body"}, "View");
    const auto &body = view["body"].get_string();
    if (view["name"].get_string().empty() || body.empty()) {
      throw std::runtime_error("Publish MySQL: Bad View");
    }
    Objects::sanitize(view["name"].get_string(),
                      Objects::SanitizeRule::ViewName);
    Objects::sanitize(body, Objects::SanitizeRule::ViewBody);
  }
}

std::string Views::snapshot_schema_state(const std::string &db_name) {
  std::string sql;
  sql += R"(
set @_sql_views = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'name', `name`
)), json_array())
from (
    select `TABLE_NAME` as `name`
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = ')" +
         db_name + R"(' and `TABLE_TYPE` = 'VIEW'
    order by `TABLE_NAME`
) as `_sql_ordered_views`
));
)";
  return sql;
}

std::string Views::generate(const jsonio::json &views,
                            const Context &context) {
  return Views{views, context}.generate();
}

Views::Views(const jsonio::json &views, const Context &context)
    : views_(views), context_(context) {}

std::string Views::generate() {
  remove_extra_views();
  create_views();
  return sql_;
}

void Views::remove_extra_views() {
  sql_ += R"(
set @all_views = '';
)";
  for (const auto &view : views_.get_array()) {
    sql_ += R"(
set @all_views = concat(@all_views, '{)" +
            view["name"].get_string() + R"(}');
)";
  }
  sql_ += R"(
set @sub_query = null;
select group_concat(concat('`)" +
          context_.db_name + R"(`.`', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from )" +
          Objects::planned_views_from_json() +
          R"(
  where instr(@all_views, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra view.\';'
,
  concat('DROP VIEW ', @sub_query, ';')
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_views = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_views_from_json() +
          R"(
      where instr(@all_views, concat('{', `name`, '}')) != 0
      order by `name`
  ) as `_sql_ordered_views`
);
)";
}

void Views::create_views() {
  for (const auto &view : views_.get_array()) {
    const auto &view_name = view["name"].get_string();
    const auto view_sql = "CREATE OR REPLACE VIEW `" + context_.db_name +
                          "`.`" + view_name + "` AS " +
                          view["body"].get_string() + ";";
    const auto escaped_view = Objects::escape_sql_string(view_sql);
    sql_ += R"(
set @qry = ')" +
            escaped_view + R"(';
)";
    sql_ += context_.exec;
    sql_ += R"(
set @old_view = null;
select `name` into @old_view
  from )" + Objects::planned_views_from_json() +
            R"(
  where `name` = ')" +
            view_name + R"(';
set @_sql_views = if(isnull(@old_view),
  json_array_append(@_sql_views, '$', json_object(
      'name', ')" +
            view_name + R"('
  )),
  @_sql_views
);
)";
  }
}
