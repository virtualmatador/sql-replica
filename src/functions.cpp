#include "functions.h"

#include "objects.h"
#include "routines.h"

std::string Functions::function_params(const jsonio::json &function) {
  std::string params;
  for (const auto &param : function["params"].get_array()) {
    if (!params.empty()) {
      params += ", ";
    }
    params +=
        "`" + param["name"].get_string() + "` " + param["type"].get_string();
  }
  return params;
}

void Functions::validate(const jsonio::json &functions) {
  for (const auto &function : functions.get_array()) {
    Objects::validate_fields(
        function, {"name", "returns", "characteristics", "params", "body"},
        "Function");
    Objects::sanitize(function["name"].get_string(), "\\'`");
    Objects::sanitize(function["returns"].get_string(), "\\'`");
    Routines::validate_routine_characteristics(function);
    for (const auto &param : function["params"].get_array()) {
      Objects::validate_fields(param, {"name", "type"}, "Function Param");
      Objects::sanitize(param["name"].get_string(), "\\'`");
      Objects::sanitize(param["type"].get_string(), "\\'`");
    }
  }
}

std::string Functions::generate(const jsonio::json &functions,
                                const Context &context) {
  return Functions{functions, context}.generate();
}

Functions::Functions(const jsonio::json &functions, const Context &context)
    : functions_(functions), context_(context) {}

std::string Functions::generate() {
  remove_extra_functions();
  apply_functions();
  return sql_;
}

void Functions::remove_extra_functions() {
  // Remove extra functions
  sql_ += R"(
set @all_functions = '';
)";
  for (const auto &function : functions_.get_array()) {
    sql_ += R"(
set @all_functions = concat(@all_functions, '{)" +
            function["name"].get_string() + R"(}');
)";
  }
  sql_ += R"(
set @sub_query = null;
select group_concat(concat('`)" +
          context_.db_name + R"(`.`', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from )" +
          Objects::planned_routines_from_json() +
          R"(
  where `type` = 'FUNCTION' and
      instr(@all_functions, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra function.\';'
,
  concat('DROP FUNCTION ', @sub_query, ';')
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_routines = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'type', `type`,
      'body', `body`,
      'returns', `returns`,
      'params', `params`,
      'data_access', `data_access`,
      'deterministic', `deterministic`,
      'security', `security`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_routines_from_json() +
          R"(
      where not (`type` = 'FUNCTION' and
          instr(@all_functions, concat('{', `name`, '}')) = 0)
      order by `type`, `name`
  ) as `_sql_ordered_routines`
);
)";
}

void Functions::apply_functions() {
  // Apply functions
  if (functions_.get_array().size() != 0) {
    sql_ += R"(
set @function_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));
)";
  }
  for (const auto &function : functions_.get_array()) {
    const auto characteristics = Routines::routine_characteristics(function);
    const auto data_access = Routines::routine_data_access(function);
    const auto deterministic = Routines::routine_deterministic(function);
    const auto security = Routines::routine_security(function);
    sql_ += R"(
set @old_body = null;
set @old_returns = null;
set @old_data_access = null;
set @old_deterministic = null;
set @old_security = null;
set @old_params = null;
select `body`, `returns`, `data_access`, `deterministic`, `security`
  into @old_body, @old_returns, @old_data_access, @old_deterministic,
      @old_security
  from )" + Objects::planned_routines_from_json() +
            R"(
  where `type` = 'FUNCTION' and
      `name` = ')" +
            function["name"].get_string() + R"(';
select `params`
  into @old_params
  from )" + Objects::planned_routines_from_json() +
            R"(
  where `type` = 'FUNCTION' and
      `name` = ')" +
            function["name"].get_string() + R"(';
set @function_changed =
  isnull(@old_body) or
  @old_body != ')" +
            Objects::escape_sql_string(function["body"].get_string()) +
            R"(' or
  ifnull(@old_returns, '') != ')" +
            function["returns"].get_string() + R"(' or
)" +
            (data_access.empty() ? ""
                                 : R"(    ifnull(@old_data_access, '') != ')" +
                                       data_access + R"(' or
)") +
            (deterministic.empty()
                 ? ""
                 : R"(    ifnull(@old_deterministic, '') != ')" +
                       deterministic +
                       R"(' or
)") +
            (security.empty()
                 ? ""
                 : R"(    ifnull(@old_security, '') != ')" + security + R"(' or
)") +
            R"(
  ifnull(@old_params, '') != ')" +
            function_params(function) + R"(';
set @qry = if (@function_changed,
  'DROP FUNCTION IF EXISTS `)" +
            context_.db_name + R"(`.`)" + function["name"].get_string() + R"(`;'
,
  'SET @r = \'Function Drop )" +
            function["name"].get_string() + R"( is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_routines = if(@function_changed,
  (
      select coalesce(json_arrayagg(json_object(
          'name', `name`,
          'type', `type`,
          'body', `body`,
          'returns', `returns`,
          'params', `params`,
          'data_access', `data_access`,
          'deterministic', `deterministic`,
          'security', `security`
      )), json_array())
      from (
          select *
          from )" +
            Objects::planned_routines_from_json() +
            R"(
          where not (`type` = 'FUNCTION' and
              `name` = ')" +
            function["name"].get_string() +
            R"(')
          order by `type`, `name`
      ) as `_sql_ordered_routines`
  ),
  @_sql_routines
);
)";
    sql_ += R"(
set @qry = if (@function_changed,
  concat('DELIMITER ', @function_delimiter, '\n', 'CREATE FUNCTION `)" +
            context_.db_name + R"(`.`)" + function["name"].get_string() +
            R"(`()" + function_params(function) + R"() RETURNS )" +
            function["returns"].get_string() + " " +
            (characteristics.empty() ? "" : characteristics + " ") +
            R"(BEGIN )" +
            Objects::escape_sql_string(function["body"].get_string()) +
            R"( END ', @function_delimiter, '\n', 'DELIMITER ;')
,
  'SET @r = \'Function Create )" +
            function["name"].get_string() + R"( is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_routines = if(@function_changed,
  json_array_append(@_sql_routines, '$', json_object(
      'name', ')" +
            function["name"].get_string() +
            R"(',
      'type', 'FUNCTION',
      'body', ')" +
            Objects::escape_sql_string(function["body"].get_string()) +
            R"(',
      'returns', ')" +
            function["returns"].get_string() +
            R"(',
      'params', ')" +
            function_params(function) +
            R"(',
      'data_access', ')" +
            data_access +
            R"(',
      'deterministic', ')" +
            deterministic +
            R"(',
      'security', ')" +
            security + R"('
  )),
  @_sql_routines
);
)";
  }
}
