#ifndef ROUTINES_H
#define ROUTINES_H

#include <string>

#include <json.hpp>

#include "context.h"

class Routines {
public:
  static void validate(const jsonio::json &procedures);
  static std::string snapshot_schema_state(const std::string &db_name);
  static std::string generate(const jsonio::json &procedures,
                              const Context &context);

  static const jsonio::json_arr &
  routine_characteristic_values(const jsonio::json &routine);
  static std::string routine_characteristics(const jsonio::json &routine);
  static std::string routine_data_access(const jsonio::json &routine);
  static std::string routine_deterministic(const jsonio::json &routine);
  static std::string routine_security(const jsonio::json &routine);
  static void validate_routine_characteristics(const jsonio::json &routine);

private:
  Routines(const jsonio::json &procedures, const Context &context);

  std::string generate();
  void remove_extra_procedures();
  void apply_procedures();

  static std::string procedure_params(const jsonio::json &procedure);

  const jsonio::json &procedures_;
  const Context &context_;
  std::string sql_;
};

#endif // ROUTINES_H
