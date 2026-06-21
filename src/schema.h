#ifndef SCHEMA_H
#define SCHEMA_H

#include <string>

#include <json.hpp>

class Schema {
public:
  Schema(const jsonio::json &schema, bool report, bool dry_run);

  std::string replicate_sql() const;

private:
  const jsonio::json_obj &schema_object() const;
  const std::string &schema_name() const;
  const jsonio::json &section_or_null(const char *section) const;

  const jsonio::json &schema_;
  bool report_;
  bool dry_run_;
};

#endif // SCHEMA_H
