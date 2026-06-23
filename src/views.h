#ifndef VIEWS_H
#define VIEWS_H

#include <string>

#include <json.hpp>

#include "context.h"

class Views {
public:
  static void validate(const jsonio::json &views);
  static std::string snapshot_schema_state(const std::string &db_name);
  static std::string generate(const jsonio::json &views,
                              const Context &context);

private:
  Views(const jsonio::json &views, const Context &context);

  std::string generate();
  void remove_extra_views();
  void create_views();

  const jsonio::json &views_;
  const Context &context_;
  std::string sql_;
};

#endif // VIEWS_H
