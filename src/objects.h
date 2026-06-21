#ifndef OBJECTS_H
#define OBJECTS_H

#include <initializer_list>
#include <string>

#include <json.hpp>

class Objects {
public:
  static bool equals_ignore_case(const std::string &lhs, const char *rhs);
  static void sanitize(const std::string &input, const char *bad_chars);
  static void validate_fields(const jsonio::json &object,
                              std::initializer_list<const char *> allowed,
                              const char *kind);
  static std::string escape_sql_string(const std::string &input);
  static bool is_null(const jsonio::json &value);

  static std::string
  planned_tables_from_json(const std::string &json = "@_sql_tables");
  static std::string
  planned_columns_from_json(const std::string &json = "@_sql_columns");
  static std::string
  planned_indexes_from_json(const std::string &json = "@_sql_indexes");
  static std::string planned_foreign_keys_from_json(
      const std::string &json = "@_sql_foreign_keys");
  static std::string
  planned_views_from_json(const std::string &json = "@_sql_views");
  static std::string
  planned_users_from_json(const std::string &json = "@_sql_users");
  static std::string
  planned_permissions_from_json(const std::string &json = "@_sql_permissions");
  static std::string
  planned_routines_from_json(const std::string &json = "@_sql_routines");
};

#endif // OBJECTS_H
