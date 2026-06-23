#include "objects.h"

#include <algorithm>
#include <cctype>
#include <string.h>

void Objects::sanitize(const std::string &input, const char *bad_chars) {
  while (*bad_chars) {
    if (input.find(*bad_chars++) != std::string::npos) {
      throw std::runtime_error(input.c_str());
    }
  }
}

bool Objects::equals_ignore_case(const std::string &lhs, const char *rhs) {
  return strcasecmp(lhs.c_str(), rhs) == 0;
}

void Objects::validate_fields(const jsonio::json &object,
                              std::initializer_list<const char *> allowed,
                              const char *kind) {
  for (const auto &[key, value] : object.get_object()) {
    if (std::find(allowed.begin(), allowed.end(), key) == allowed.end()) {
      throw std::runtime_error(std::string{"Publish MySQL: Unknown "} + kind +
                               " Field");
    }
  }
}

std::string Objects::escape_sql_string(const std::string &input) {
  std::string output;
  for (const auto c : input) {
    if (c == '\\' || c == '\'') {
      output += '\\';
    }
    output += c;
  }
  return output;
}

bool Objects::is_null(const jsonio::json &value) {
  return value.type() == jsonio::JsonType::J_NULL;
}

std::string Objects::planned_tables_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `comment` varchar(2048) path '$.comment',
        `type` varchar(64) path '$.type',
        `engine` varchar(64) path '$.engine'
    )) as `planned_tables`)";
}

std::string Objects::planned_columns_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `comment` varchar(1024) path '$.comment',
        `type` text path '$.type',
        `default_value` text path '$.default' null on empty,
        `nullable` varchar(3) path '$.nullable',
        `auto` bool path '$.auto',
        `ordinal` int path '$.ordinal'
    )) as `planned_columns`)";
}

std::string Objects::planned_indexes_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `foreign_key` bool path '$.foreign_key'
    )) as `planned_indexes`)";
}

std::string Objects::planned_foreign_keys_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `table` varchar(255) path '$.table',
        `name` varchar(255) path '$.name',
        `key_def` text path '$.key_def',
        `referenced_table` varchar(255) path '$.referenced_table',
        `f_key_def` text path '$.f_key_def',
        `update_rule` varchar(64) path '$.update',
        `delete_rule` varchar(64) path '$.delete'
    )) as `planned_foreign_keys`)";
}

std::string Objects::planned_views_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `name` varchar(255) path '$.name'
    )) as `planned_views`)";
}

std::string Objects::planned_users_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `name` varchar(255) path '$.name'
    )) as `planned_users`)";
}

std::string Objects::planned_permissions_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `user` varchar(255) path '$.user',
        `type` varchar(32) path '$.type',
        `subject` varchar(255) path '$.subject',
        `operations` text path '$.operations'
    )) as `planned_permissions`)";
}

std::string Objects::planned_routines_from_json(const std::string &json) {
  return "json_table(" + json +
         R"(, '$[*]' columns (
        `name` varchar(255) path '$.name',
        `type` varchar(32) path '$.type',
        `comment` text path '$.comment'
    )) as `planned_routines`)";
}
