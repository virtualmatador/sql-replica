#ifndef TABLES_H
#define TABLES_H

#include <map>
#include <string>
#include <utility>

#include <json.hpp>

#include "context.h"

class Tables {
public:
  static void validate(const jsonio::json &tables,
                       const std::string &bad_prefix);
  static std::string snapshot_schema_state(const std::string &db_name);
  static std::string generate(const jsonio::json &tables,
                              const Context &context);

private:
  Tables(const jsonio::json &tables, const Context &context);

  std::string generate();
  void create_tables_with_prefix();
  void remove_extra_views();
  void mark_extra_tables();
  void apply_table_names();
  void apply_table_engine();
  void apply_columns_and_keys();
  void drop_wrong_foreign_keys();
  void apply_column_properties();
  void remove_extra_defaults();
  void remove_extra_tables();
  void create_foreign_keys();
  void create_views();

  static void validate_engine(const std::string &engine);
  static void validate_key_type(const std::string &type);
  static void validate_foreign_key_action(const std::string &action);

  const jsonio::json &tables_;
  const Context &context_;
  std::string sql_;
  std::map<std::string, std::string> engines_;
  std::map<std::string,
           std::map<std::string, std::pair<std::string, std::string>>>
      fk_flatten_columns_;
};

#endif // TABLES_H
