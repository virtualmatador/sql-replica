#include "routines.h"

#include "objects.h"

#include <string.h>

std::string Routines::procedure_params(const jsonio::json &procedure) {
  std::string params;
  for (const auto &param : procedure["params"].get_array()) {
    if (!params.empty()) {
      params += ", ";
    }
    params += param["mode"].get_string() + " `" + param["name"].get_string() +
              "` " + param["type"].get_string();
  }
  return params;
}

const jsonio::json_arr &
Routines::routine_characteristic_values(const jsonio::json &routine) {
  return routine["characteristics"].get_array();
}

std::string Routines::routine_characteristics(const jsonio::json &routine) {
  std::string result;
  for (const auto &value : routine_characteristic_values(routine)) {
    if (!result.empty()) {
      result += " ";
    }
    result += value.get_string();
  }
  return result;
}

std::string Routines::routine_data_access(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    const auto &text = value.get_string();
    if (strcasecmp(text.c_str(), "CONTAINS SQL") == 0 ||
        strcasecmp(text.c_str(), "NO SQL") == 0 ||
        strcasecmp(text.c_str(), "READS SQL DATA") == 0 ||
        strcasecmp(text.c_str(), "MODIFIES SQL DATA") == 0) {
      return text;
    }
  }
  return "";
}

std::string Routines::routine_deterministic(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    const auto &text = value.get_string();
    if (strcasecmp(text.c_str(), "DETERMINISTIC") == 0) {
      return "YES";
    }
    if (strcasecmp(text.c_str(), "NOT DETERMINISTIC") == 0) {
      return "NO";
    }
  }
  return "";
}

std::string Routines::routine_security(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    const auto &text = value.get_string();
    if (strncasecmp(text.c_str(), "SQL SECURITY ", 13) == 0) {
      return text.substr(13);
    }
  }
  return "";
}

void Routines::validate_routine_characteristics(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    Objects::sanitize(value.get_string(), "\\'`");
  }
}

void Routines::validate(const jsonio::json &procedures) {
  for (const auto &procedure : procedures.get_array()) {
    Objects::validate_fields(
        procedure, {"name", "characteristics", "params", "body"}, "Procedure");
    Objects::sanitize(procedure["name"].get_string(), "\\'`");
    validate_routine_characteristics(procedure);
    for (const auto &param : procedure["params"].get_array()) {
      Objects::validate_fields(param, {"mode", "name", "type"},
                               "Procedure Param");
      if (const auto &mode = param["mode"].get_string();
          strcasecmp(mode.c_str(), "IN") != 0 &&
          strcasecmp(mode.c_str(), "OUT") != 0 &&
          strcasecmp(mode.c_str(), "INOUT") != 0) {
        throw std::runtime_error("Publish MySQL: Bad Procedure Param Mode");
      }
      Objects::sanitize(param["name"].get_string(), "\\'`");
      Objects::sanitize(param["type"].get_string(), "\\'`");
    }
  }
}

std::string Routines::generate(const jsonio::json &procedures,
                               const Context &context) {
  return Routines{procedures, context}.generate();
}

Routines::Routines(const jsonio::json &procedures, const Context &context)
    : procedures_(procedures), context_(context) {}

std::string Routines::generate() {
  remove_extra_procedures();
  apply_procedures();
  return sql_;
}

void Routines::remove_extra_procedures() {
  // Remove extra procedures
  sql_ += R"(
set @all_procedures = '';
)";
  for (const auto &procedure : procedures_.get_array()) {
    sql_ += R"(
set @all_procedures = concat(@all_procedures, '{)" +
            procedure["name"].get_string() + R"(}');
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
  where `type` = 'PROCEDURE' and
      instr(@all_procedures, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra procedure.\';'
,
  concat('DROP PROCEDURE ', @sub_query, ';')
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
      where not (`type` = 'PROCEDURE' and
          instr(@all_procedures, concat('{', `name`, '}')) = 0)
      order by `type`, `name`
  ) as `_sql_ordered_routines`
);
)";
}

void Routines::apply_procedures() {
  // Apply procedures
  if (procedures_.get_array().size() != 0) {
    sql_ += R"(
set @procedure_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));
)";
  }
  for (const auto &procedure : procedures_.get_array()) {
    const auto characteristics = Routines::routine_characteristics(procedure);
    const auto data_access = Routines::routine_data_access(procedure);
    const auto deterministic = Routines::routine_deterministic(procedure);
    const auto security = Routines::routine_security(procedure);
    sql_ += R"(
set @old_body = null;
set @old_data_access = null;
set @old_deterministic = null;
set @old_security = null;
set @old_params = null;
select `body`, `data_access`, `deterministic`, `security`
  into @old_body, @old_data_access, @old_deterministic, @old_security
  from )" + Objects::planned_routines_from_json() +
            R"(
  where `type` = 'PROCEDURE' and
      `name` = ')" +
            procedure["name"].get_string() + R"(';
select `params`
  into @old_params
  from )" + Objects::planned_routines_from_json() +
            R"(
  where `type` = 'PROCEDURE' and
      `name` = ')" +
            procedure["name"].get_string() + R"(';
set @procedure_changed =
  isnull(@old_body) or
  @old_body != ')" +
            Objects::escape_sql_string(procedure["body"].get_string()) +
            R"(' or
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
            procedure_params(procedure) + R"(';
set @qry = if (@procedure_changed,
  'DROP PROCEDURE IF EXISTS `)" +
            context_.db_name + R"(`.`)" + procedure["name"].get_string() +
            R"(`;'
,
  'SET @r = \'Procedure )" +
            procedure["name"].get_string() + R"( is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_routines = if(@procedure_changed,
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
          where not (`type` = 'PROCEDURE' and
              `name` = ')" +
            procedure["name"].get_string() +
            R"(')
          order by `type`, `name`
      ) as `_sql_ordered_routines`
  ),
  @_sql_routines
);
)";
    sql_ += R"(
set @qry = if (@procedure_changed,
  concat('DELIMITER ', @procedure_delimiter, '\n', 'CREATE PROCEDURE `)" +
            context_.db_name + R"(`.`)" + procedure["name"].get_string() +
            R"(`()" + procedure_params(procedure) + R"() )" +
            (characteristics.empty() ? "" : characteristics + " ") +
            R"(BEGIN )" +
            Objects::escape_sql_string(procedure["body"].get_string()) +
            R"( END ', @procedure_delimiter, '\n', 'DELIMITER ;')
,
  'SET @r = \'Procedure )" +
            procedure["name"].get_string() + R"( is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_routines = if(@procedure_changed,
  json_array_append(@_sql_routines, '$', json_object(
      'name', ')" +
            procedure["name"].get_string() +
            R"(',
      'type', 'PROCEDURE',
      'body', ')" +
            Objects::escape_sql_string(procedure["body"].get_string()) +
            R"(',
      'returns', '',
      'params', ')" +
            procedure_params(procedure) +
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
std::string Routines::snapshot_schema_state(const std::string &db_name) {
  std::string sql;
  sql += R"(
set @_sql_routines = if(isnull(@old_db), json_array(), (
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
    select
        `r`.`ROUTINE_NAME` as `name`,
        `r`.`ROUTINE_TYPE` as `type`,
        if(
            upper(left(trim(`r`.`ROUTINE_DEFINITION`), 5)) = 'BEGIN' and
                upper(right(trim(`r`.`ROUTINE_DEFINITION`), 3)) = 'END',
            trim(substr(trim(`r`.`ROUTINE_DEFINITION`), 6,
                length(trim(`r`.`ROUTINE_DEFINITION`)) - 8)),
            trim(`r`.`ROUTINE_DEFINITION`)
        ) as `body`,
        if(`r`.`ROUTINE_TYPE` = 'FUNCTION', `r`.`DTD_IDENTIFIER`, '') as `returns`,
        coalesce(`p`.`params`, '') as `params`,
        `r`.`SQL_DATA_ACCESS` as `data_access`,
        `r`.`IS_DETERMINISTIC` as `deterministic`,
        `r`.`SECURITY_TYPE` as `security`
    from `INFORMATION_SCHEMA`.`ROUTINES` as `r`
    left join (
        select
            `SPECIFIC_SCHEMA`,
            `ROUTINE_TYPE`,
            `SPECIFIC_NAME`,
            group_concat(
                if(`ROUTINE_TYPE` = 'PROCEDURE',
                    concat(`PARAMETER_MODE`, ' `', `PARAMETER_NAME`, '` ', `DTD_IDENTIFIER`),
                    concat('`', `PARAMETER_NAME`, '` ', `DTD_IDENTIFIER`)
                )
                order by `ORDINAL_POSITION` separator ', '
            ) as `params`
        from `INFORMATION_SCHEMA`.`PARAMETERS`
        where
            `SPECIFIC_SCHEMA` = ')" +
         db_name + R"(' and
            `PARAMETER_NAME` is not null
        group by `SPECIFIC_SCHEMA`, `ROUTINE_TYPE`, `SPECIFIC_NAME`
    ) as `p`
    on
        `p`.`SPECIFIC_SCHEMA` = `r`.`ROUTINE_SCHEMA` and
        `p`.`ROUTINE_TYPE` = `r`.`ROUTINE_TYPE` and
        `p`.`SPECIFIC_NAME` = `r`.`ROUTINE_NAME`
    where
        `r`.`ROUTINE_SCHEMA` = ')" +
         db_name + R"(' and
        `r`.`ROUTINE_TYPE` in ('FUNCTION', 'PROCEDURE')
    order by `r`.`ROUTINE_TYPE`, `r`.`ROUTINE_NAME`
) as `_sql_ordered_routines`
));
)";
  return sql;
}
