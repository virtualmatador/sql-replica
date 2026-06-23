#include "routines.h"

#include "objects.h"

#include <cctype>

namespace {
bool is_word_char(const char c) {
  return std::isalnum(static_cast<unsigned char>(c)) || c == '_';
}

std::string upper_string(std::string value) {
  for (auto &c : value) {
    c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
  }
  return value;
}

std::size_t find_keyword(const std::string &text, const char *keyword) {
  const auto upper = upper_string(text);
  const auto needle = upper_string(keyword);
  auto pos = upper.find(needle);
  while (pos != std::string::npos) {
    const bool left_ok = pos == 0 || !is_word_char(upper[pos - 1]);
    const auto end = pos + needle.size();
    const bool right_ok = end == upper.size() || !is_word_char(upper[end]);
    if (left_ok && right_ok) {
      return pos;
    }
    pos = upper.find(needle, pos + 1);
  }
  return std::string::npos;
}

void skip_spaces(const std::string &text, std::size_t &pos) {
  while (pos < text.size() &&
         std::isspace(static_cast<unsigned char>(text[pos]))) {
    ++pos;
  }
}

std::string read_identifier(const std::string &text, std::size_t &pos) {
  skip_spaces(text, pos);
  if (pos >= text.size()) {
    return "";
  }
  if (text[pos] == '`') {
    ++pos;
    std::string result;
    while (pos < text.size()) {
      if (text[pos] == '`') {
        ++pos;
        return result;
      }
      result += text[pos++];
    }
    return "";
  }

  std::string result;
  while (pos < text.size()) {
    const auto c = text[pos];
    if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_' && c != '$') {
      break;
    }
    result += c;
    ++pos;
  }
  return result;
}
} // namespace

void Routines::validate(const jsonio::json &routines) {
  for (const auto &routine : routines.get_array()) {
    const auto &[type, name] = routine_type_and_name(routine.get_string());
    if (type.empty() || name.empty()) {
      throw std::runtime_error("Publish MySQL: Bad Routine");
    }
    Objects::sanitize(name, "\\'`");
  }
}

std::string Routines::generate(const jsonio::json &routines,
                               const Context &context) {
  return Routines{routines, context}.generate();
}

Routines::Routines(const jsonio::json &routines, const Context &context)
    : routines_(routines), context_(context) {}

std::string Routines::generate() {
  remove_extra_routines();
  apply_routines();
  return sql_;
}

std::pair<std::string, std::string>
Routines::routine_type_and_name(const std::string &routine) {
  auto type = std::string{"PROCEDURE"};
  auto pos = find_keyword(routine, "PROCEDURE");
  auto function_pos = find_keyword(routine, "FUNCTION");
  if (function_pos != std::string::npos &&
      (pos == std::string::npos || function_pos < pos)) {
    type = "FUNCTION";
    pos = function_pos;
  }
  if (pos == std::string::npos) {
    return {"", ""};
  }

  pos += type.size();
  auto first = read_identifier(routine, pos);
  skip_spaces(routine, pos);
  if (pos < routine.size() && routine[pos] == '.') {
    ++pos;
    const auto second = read_identifier(routine, pos);
    if (!second.empty()) {
      first = second;
    }
  }
  return {type, first};
}

void Routines::remove_extra_routines() {
  sql_ += R"(
set @all_routines = '';
)";
  for (const auto &routine : routines_.get_array()) {
    const auto &[type, name] = routine_type_and_name(routine.get_string());
    sql_ += R"(
set @all_routines = concat(@all_routines, '{)" +
            type + ":" + name + R"(}');
)";
  }
  sql_ += R"(
set @sub_query = null;
select group_concat(
    concat('DROP ', `type`, ' `)" +
          context_.db_name + R"(`.`', `name`, '`;') SEPARATOR ' ')
  into @sub_query
  from )" +
          Objects::planned_routines_from_json() +
          R"(
  where instr(@all_routines, concat('{', `type`, ':', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra routine.\';'
,
  @sub_query
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_routines = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'type', `type`,
      'comment', `comment`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_routines_from_json() +
          R"(
      where instr(@all_routines, concat('{', `type`, ':', `name`, '}')) != 0
      order by `type`, `name`
  ) as `_sql_ordered_routines`
);
)";
}

void Routines::apply_routines() {
  if (routines_.get_array().size() != 0) {
    sql_ += R"(
set @routine_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));
)";
  }
  for (const auto &routine : routines_.get_array()) {
    const auto routine_sql = routine.get_string();
    const auto &[type, name] = routine_type_and_name(routine_sql);
    const auto escaped_routine = Objects::escape_sql_string(routine_sql);
    sql_ += R"(
set @old_comment = null;
set @routine_hash = sha2(')" +
            escaped_routine + R"(', 256);
select `comment`
  into @old_comment
  from )" + Objects::planned_routines_from_json() +
            R"(
  where `type` = ')" +
            type + R"(' and
      `name` = ')" +
            name + R"(';
set @routine_changed =
  isnull(@old_comment) or
  if(
      @old_comment regexp 'SQLR_HASH:[0-9a-fA-F]{64}$',
      lower(right(@old_comment, 64)),
      ''
  ) != @routine_hash;
set @qry = if (@routine_changed and not isnull(@old_comment),
  'DROP )" +
            type + R"( `)" +
            context_.db_name + R"(`.`)" + name + R"(`;'
,
  if(isnull(@old_comment),
    'SET @r = \'Routine )" +
            name + R"( absence is ok.\';'
  ,
    'SET @r = \'Routine )" +
            name + R"( is ok.\';'
  )
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_routines = if(@routine_changed,
  (
      select coalesce(json_arrayagg(json_object(
          'name', `name`,
          'type', `type`,
          'comment', `comment`
      )), json_array())
      from (
          select *
          from )" +
            Objects::planned_routines_from_json() +
            R"(
          where not (`type` = ')" +
            type + R"(' and
              `name` = ')" +
            name +
            R"(')
          order by `type`, `name`
      ) as `_sql_ordered_routines`
  ),
  @_sql_routines
);
)";
    sql_ += R"(
set @qry = if (@routine_changed,
  concat('DELIMITER ', @routine_delimiter, '\n', ')" +
            escaped_routine +
            R"( ', @routine_delimiter, '\n', 'DELIMITER ;')
,
  'SET @r = \'Routine )" +
            name + R"( is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @routine_comment = null;
select `ROUTINE_COMMENT`
  into @routine_comment
  from `INFORMATION_SCHEMA`.`ROUTINES`
  where `ROUTINE_SCHEMA` = ')" +
            context_.db_name + R"(' and
      `ROUTINE_TYPE` = ')" +
            type + R"(' and
      `ROUTINE_NAME` = ')" +
            name + R"(';
set @routine_comment = concat(
  regexp_replace(
      ifnull(@routine_comment, ''),
      '\n?SQLR_HASH:[0-9a-fA-F]{64}$',
      ''
  ),
  '\nSQLR_HASH:',
  @routine_hash
);
set @qry = if (@routine_changed,
  concat('ALTER )" +
            type + R"( `)" +
            context_.db_name + R"(`.`)" + name +
            R"(` COMMENT ', quote(@routine_comment), ';')
,
  'SET @r = \'Routine comment )" +
            name + R"( is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_routines = if(@routine_changed,
  json_array_append(@_sql_routines, '$', json_object(
      'name', ')" +
            name +
            R"(',
      'type', ')" +
            type +
            R"(',
      'comment', @routine_comment
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
    'comment', `comment`
)), json_array())
from (
    select
        `r`.`ROUTINE_NAME` as `name`,
        `r`.`ROUTINE_TYPE` as `type`,
        `r`.`ROUTINE_COMMENT` as `comment`
    from `INFORMATION_SCHEMA`.`ROUTINES` as `r`
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
