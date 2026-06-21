#ifndef FUNCTIONS_H
#define FUNCTIONS_H

#include <string>

#include <json.hpp>

#include "context.h"

class Functions {
public:
  static void validate(const jsonio::json &functions);
  static std::string generate(const jsonio::json &functions,
                              const Context &context);

private:
  Functions(const jsonio::json &functions, const Context &context);

  std::string generate();
  void remove_extra_functions();
  void apply_functions();

  static std::string function_params(const jsonio::json &function);

  const jsonio::json &functions_;
  const Context &context_;
  std::string sql_;
};

#endif // FUNCTIONS_H
