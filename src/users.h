#ifndef USERS_H
#define USERS_H

#include <string>
#include <vector>

#include <json.hpp>

#include "context.h"

class Users {
public:
  static void validate(const jsonio::json &users);
  static std::string snapshot_schema_state(const std::string &db_name);
  static std::string generate(const jsonio::json &users,
                              const Context &context);

private:
  Users(const jsonio::json &users, const Context &context);

  std::string generate();
  void remove_unlisted_user_permissions();
  void apply_users();

  static std::string permission_type(const jsonio::json &permission);
  static std::string permission_grant_type(const std::string &type);
  static std::vector<const char *>
  permission_operations(const std::string &type);

  const jsonio::json &users_;
  const Context &context_;
  std::string sql_;
};

#endif // USERS_H
