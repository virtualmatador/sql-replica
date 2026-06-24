#ifndef ROUTINES_H
#define ROUTINES_H

#include <string>

#include <json.hpp>

#include "context.h"

class Routines {
public:
  static void validate(const jsonio::json &routines);
  static std::string snapshot_schema_state(const std::string &db_name);
  static std::string generate(const jsonio::json &routines,
                              const Context &context);

private:
  Routines(const jsonio::json &routines, const Context &context);

  std::string generate();
  void remove_extra_routines();
  void apply_routines();

  const jsonio::json &routines_;
  const Context &context_;
  std::string sql_;
};

#endif // ROUTINES_H
