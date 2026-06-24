#include "objects.h"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <map>
#include <stdexcept>
#include <string.h>
#include <utility>
#include <vector>

#ifndef SQLR_SANITIZE_RULES
#define SQLR_SANITIZE_RULES "sanitize_rules.json"
#endif

namespace {

struct Replacement {
  std::string from;
  std::string to;
};

struct SanitizeRuleConfig {
  std::string reject;
  bool lower_case;
  std::vector<Replacement> replacements;
  std::vector<Replacement> values;
};

const char *sanitize_rule_name(Objects::SanitizeRule rule) {
  switch (rule) {
  case Objects::SanitizeRule::DatabaseName:
    return "database-name";
  case Objects::SanitizeRule::TableName:
    return "table-name";
  case Objects::SanitizeRule::TableId:
    return "table-id";
  case Objects::SanitizeRule::ColumnName:
    return "column-name";
  case Objects::SanitizeRule::ColumnId:
    return "column-id";
  case Objects::SanitizeRule::KeyName:
    return "key-name";
  case Objects::SanitizeRule::ForeignKeyName:
    return "foreign-key-name";
  case Objects::SanitizeRule::ForeignTableName:
    return "foreign-table-name";
  case Objects::SanitizeRule::RoutineName:
    return "routine-name";
  case Objects::SanitizeRule::UserName:
    return "user-name";
  case Objects::SanitizeRule::PermissionSubject:
    return "permission-subject";
  case Objects::SanitizeRule::ViewName:
    return "view-name";
  case Objects::SanitizeRule::SqlExpression:
    return "sql-expression";
  case Objects::SanitizeRule::ViewBody:
    return "view-body";
  case Objects::SanitizeRule::MysqlColumnType:
    return "mysql-column-type";
  }
  throw std::runtime_error("Publish MySQL: Unknown Sanitize Rule");
}

std::vector<Replacement> read_replacements(const jsonio::json &rule,
                                           const char *field) {
  std::vector<Replacement> replacements;
  if (const auto entries = rule.at(field); entries) {
    for (const auto &entry : entries->get_array()) {
      replacements.push_back(
          {entry["from"].get_string(), entry["to"].get_string()});
    }
  }
  return replacements;
}

std::map<std::string, SanitizeRuleConfig> read_sanitize_rules() {
  std::ifstream stream{SQLR_SANITIZE_RULES};
  if (!stream) {
    throw std::runtime_error("Publish MySQL: Missing Sanitize Rules");
  }

  jsonio::json rules_json;
  stream >> rules_json;

  std::map<std::string, SanitizeRuleConfig> rules;
  for (const auto &[name, rule] : rules_json.get_object()) {
    auto reject = std::string{};
    if (const auto reject_value = rule.at("reject"); reject_value) {
      reject = reject_value->get_string();
    }
    auto lower_case = false;
    if (const auto lower_case_value = rule.at("lower-case");
        lower_case_value && lower_case_value->get_bool()) {
      lower_case = true;
    }
    rules[name] = {reject, lower_case, read_replacements(rule, "replace"),
                   read_replacements(rule, "values")};
  }
  return rules;
}

const std::map<std::string, SanitizeRuleConfig> &sanitize_rules() {
  static const auto rules = read_sanitize_rules();
  return rules;
}

std::string apply_sanitize_rule(std::string output,
                                const SanitizeRuleConfig &rule) {
  for (const auto c : rule.reject) {
    if (output.find(c) != std::string::npos) {
      throw std::runtime_error(output.c_str());
    }
  }
  if (rule.lower_case) {
    std::transform(output.begin(), output.end(), output.begin(),
                   [](unsigned char c) {
                     return static_cast<char>(std::tolower(c));
                   });
  }
  for (const auto &replacement : rule.replacements) {
    auto offset = std::size_t{0};
    while ((offset = output.find(replacement.from, offset)) !=
           std::string::npos) {
      output.replace(offset, replacement.from.size(), replacement.to);
      offset += replacement.to.size();
    }
  }
  for (const auto &replacement : rule.values) {
    if (output == replacement.from) {
      return replacement.to;
    }
  }
  return output;
}

const SanitizeRuleConfig &sanitize_rule_for(Objects::SanitizeRule rule) {
  const auto &rules = sanitize_rules();
  if (const auto found = rules.find(sanitize_rule_name(rule));
      found != rules.end()) {
    return found->second;
  }
  throw std::runtime_error("Publish MySQL: Unknown Sanitize Rule");
}

} // namespace

std::string Objects::sanitize(const std::string &input, SanitizeRule rule) {
  return apply_sanitize_rule(input, sanitize_rule_for(rule));
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
