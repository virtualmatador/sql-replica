#include "routines.h"

#include "objects.h"

#include <cctype>
#include <iomanip>
#include <openssl/sha.h>
#include <sstream>

namespace {
std::string upper_string(std::string value) {
  for (auto &c : value) {
    c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
  }
  return value;
}

std::string sha256(const std::string &input) {
  unsigned char digest[SHA256_DIGEST_LENGTH];
  SHA256(reinterpret_cast<const unsigned char *>(input.data()), input.size(),
         digest);
  std::ostringstream stream;
  stream << std::hex << std::setfill('0') << std::nouppercase;
  for (const auto byte : digest) {
    stream << std::setw(2) << static_cast<int>(byte);
  }
  return stream.str();
}

std::string routine_delimiter_for(const std::string &routine,
                                  const std::string &routine_hash) {
  auto hash = routine_hash;
  for (std::size_t counter = 0;; ++counter) {
    const auto delimiter = "d" + hash.substr(0, 13);
    if (routine.find(delimiter) == std::string::npos) {
      return delimiter;
    }
    hash = sha256(routine + std::to_string(counter));
  }
}

std::string routine_type(const jsonio::json &routine) {
  const auto type = upper_string(routine["type"].get_string());
  if (type != "FUNCTION" && type != "PROCEDURE") {
    throw std::runtime_error("Publish MySQL: Bad Routine Type");
  }
  return type;
}

std::string routine_sql(const jsonio::json &routine) {
  return "CREATE " + routine_type(routine) + " `" +
         routine["name"].get_string() + "`" +
         routine["definition"].get_string();
}

std::string qualified_routine_sql(const jsonio::json &routine,
                                  const std::string &db_name) {
  return "CREATE " + routine_type(routine) + " `" + db_name + "`.`" +
         routine["name"].get_string() + "`" +
         routine["definition"].get_string();
}
} // namespace

void Routines::validate(const jsonio::json &routines) {
  for (const auto &routine : routines.get_array()) {
    Objects::validate_fields(routine, {"type", "name", "definition"},
                             "Routine");
    if (routine["name"].get_string().empty() ||
        routine["definition"].get_string().empty()) {
      throw std::runtime_error("Publish MySQL: Bad Routine");
    }
    routine_type(routine);
    Objects::sanitize(routine["name"].get_string(), "\\'`");
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

void Routines::remove_extra_routines() {
  sql_ += R"(
set @all_routines = '';
)";
  for (const auto &routine : routines_.get_array()) {
    const auto type = routine_type(routine);
    const auto &name = routine["name"].get_string();
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
  for (const auto &routine : routines_.get_array()) {
    const auto type = routine_type(routine);
    const auto &name = routine["name"].get_string();
    const auto routine_sql = ::routine_sql(routine);
    const auto qualified_routine =
        qualified_routine_sql(routine, context_.db_name);
    const auto routine_hash = sha256(routine_sql);
    const auto routine_delimiter =
        routine_delimiter_for(qualified_routine, routine_hash);
    const auto create_routine_query = Objects::escape_sql_string(
        "DELIMITER " + routine_delimiter + "\n" + qualified_routine + " " +
        routine_delimiter + "\nDELIMITER ;");
    sql_ += R"(
set @old_comment = null;
set @routine_hash = ')" +
            routine_hash + R"(';
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
  ')" + create_routine_query + R"('
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
