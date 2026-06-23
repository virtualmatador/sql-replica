#include "views.h"

#include "objects.h"

#include <cctype>
#include <string.h>

namespace {

bool is_word_char(const char c) {
  return std::isalnum(static_cast<unsigned char>(c)) || c == '_';
}

bool is_quoted_text(const std::string &text, std::size_t pos) {
  const auto quote = text[pos++];
  while (pos < text.size()) {
    if (text[pos] == '\\' && pos + 1 < text.size()) {
      pos += 2;
    } else if (text[pos++] == quote) {
      return true;
    }
  }
  return false;
}

void skip_quoted_text(const std::string &text, std::size_t &pos) {
  const auto quote = text[pos++];
  while (pos < text.size()) {
    if (text[pos] == '\\' && pos + 1 < text.size()) {
      pos += 2;
    } else if (text[pos++] == quote) {
      return;
    }
  }
}

bool skip_comment(const std::string &text, std::size_t &pos) {
  if (text.compare(pos, 2, "/*") == 0) {
    const auto end = text.find("*/", pos + 2);
    pos = end == std::string::npos ? text.size() : end + 2;
    return true;
  }
  if (text.compare(pos, 2, "--") == 0 ||
      text.compare(pos, 1, "#") == 0) {
    const auto end = text.find('\n', pos + 1);
    pos = end == std::string::npos ? text.size() : end + 1;
    return true;
  }
  return false;
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
  for (std::size_t pos = 0; pos < upper.size();) {
    if (skip_comment(upper, pos)) {
      continue;
    }
    if ((upper[pos] == '\'' || upper[pos] == '"') &&
        is_quoted_text(upper, pos)) {
      skip_quoted_text(upper, pos);
      continue;
    }
    if (upper.compare(pos, needle.size(), needle) != 0) {
      ++pos;
      continue;
    }
    const bool left_ok = pos == 0 || !is_word_char(upper[pos - 1]);
    const auto end = pos + needle.size();
    const bool right_ok = end == upper.size() || !is_word_char(upper[end]);
    if (left_ok && right_ok) {
      return pos;
    }
    ++pos;
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

std::string view_name_from_sql(const std::string &view_sql) {
  auto pos = find_keyword(view_sql, "VIEW");
  if (pos == std::string::npos) {
    return "";
  }

  pos += strlen("VIEW");
  auto first = read_identifier(view_sql, pos);
  skip_spaces(view_sql, pos);
  if (pos < view_sql.size() && view_sql[pos] == '.') {
    ++pos;
    const auto second = read_identifier(view_sql, pos);
    if (!second.empty()) {
      return "";
    }
  }
  return first;
}

std::size_t view_name_position(const std::string &view_sql) {
  auto pos = find_keyword(view_sql, "VIEW");
  if (pos == std::string::npos) {
    return std::string::npos;
  }
  pos += strlen("VIEW");
  skip_spaces(view_sql, pos);
  return pos;
}

std::string qualify_view_sql(const std::string &view_sql,
                             const std::string &db_name) {
  auto pos = view_name_position(view_sql);
  if (pos == std::string::npos) {
    return view_sql;
  }
  const auto name_start = pos;
  const auto name = read_identifier(view_sql, pos);
  if (name.empty()) {
    return view_sql;
  }
  return view_sql.substr(0, name_start) + "`" + db_name + "`.`" + name + "`" +
         view_sql.substr(pos);
}

} // namespace

void Views::validate(const jsonio::json &views) {
  for (const auto &view : views.get_array()) {
    const auto name = view_name_from_sql(view.get_string());
    if (name.empty()) {
      throw std::runtime_error("Publish MySQL: Bad View");
    }
    Objects::sanitize(name, "\\'`");
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
            view_name_from_sql(view.get_string()) + R"(}');
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
    const auto view_sql = view.get_string();
    const auto view_name = view_name_from_sql(view_sql);
    const auto escaped_view =
        Objects::escape_sql_string(qualify_view_sql(view_sql,
                                                    context_.db_name));
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
