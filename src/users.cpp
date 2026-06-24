#include "users.h"

#include "objects.h"

#include <algorithm>
#include <string.h>
#include <vector>

std::string Users::permission_type(const jsonio::json &permission) {
  const auto &type = permission["type"].get_string();
  if (strcasecmp(type.c_str(), "table") == 0) {
    return "TABLE";
  }
  if (strcasecmp(type.c_str(), "function") == 0) {
    return "FUNCTION";
  }
  if (strcasecmp(type.c_str(), "procedure") == 0) {
    return "PROCEDURE";
  }
  throw std::runtime_error("Publish MySQL: Bad Permission Type");
}

std::string Users::permission_grant_type(const std::string &type) {
  return type == "TABLE" ? "" : type + " ";
}

std::vector<const char *>
Users::permission_operations(const std::string &type) {
  if (type == "TABLE") {
    return {"Select", "Insert", "Update", "Delete"};
  }
  return {"Execute"};
}

void Users::validate(const jsonio::json &users) {
  for (const auto &user : users.get_array()) {
    Objects::validate_fields(user, {"name", "permissions"}, "User");
    Objects::sanitize(user["name"].get_string(), "\\'`");
    for (const auto &permission : user["permissions"].get_array()) {
      Objects::validate_fields(permission, {"type", "subject", "operations"},
                               "Permission");
      Objects::sanitize(permission["subject"].get_string(), "\\'`");
      permission_type(permission);
    }
  }
}

std::string Users::generate(const jsonio::json &users, const Context &context) {
  return Users{users, context}.generate();
}

Users::Users(const jsonio::json &users, const Context &context)
    : users_(users), context_(context) {}

std::string Users::generate() {
  remove_unlisted_user_permissions();
  apply_users();
  return sql_;
}

void Users::remove_unlisted_user_permissions() {
  // Revoke database permissions from users not listed in this schema.
  sql_ += R"(
set @all_users = '';
)";
  for (const auto &user : users_.get_array()) {
    sql_ += R"(
set @all_users = concat(@all_users, '{)" +
            user["name"].get_string() + R"(}');
)";
  }
  sql_ += R"(
set @sub_query = null;
select group_concat(
  if(`type` = 'TABLE',
    concat('REVOKE ', `operations`, ' ON `)" +
          context_.db_name + R"(`.`', `subject`, '` FROM ''', `user`, ''';'),
    concat('REVOKE ', `operations`, ' ON ', `type`, ' `)" +
          context_.db_name + R"(`.`', `subject`, '` FROM ''', `user`, ''';')
  )
  separator ' '
)
into @sub_query
from )" + Objects::planned_permissions_from_json() +
          R"(
where instr(@all_users, concat('{', `user`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No unlisted user permissions.\';'
,
  @sub_query
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_permissions_from_json() +
          R"(
      where instr(@all_users, concat('{', `user`, '}')) != 0
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);
)";
}

void Users::apply_users() {
  // Apply users
  std::size_t index = 0;
  for (const auto &user : users_.get_array()) {
    sql_ += R"(
set @old_user = null;
select `name` into @old_user from )" +
            Objects::planned_users_from_json() +
            R"(
where `name` = ')" +
            user["name"].get_string() + R"(';
set @qry = if (isnull(@old_user),
  'CREATE USER \')" +
            user["name"].get_string() + R"(\' ACCOUNT LOCK;'
,
  'SET @r = \'User ")" +
            user["name"].get_string() + R"(" exists.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_users = if(isnull(@old_user),
  json_array_append(@_sql_users, '$', json_object(
      'name', ')" +
            user["name"].get_string() + R"('
  )),
  @_sql_users
);
)";
    sql_ += "set @all_grants = '';";
    // Revoke permissions of extra subjects
    for (const auto &permission : user["permissions"].get_array()) {
      sql_ += "\nset @all_grants = concat(@all_grants, '{";
      sql_ += permission_type(permission);
      sql_ += ":";
      sql_ += permission["subject"].get_string();
      sql_ += "}');";
    }
    sql_ += R"(
set @sub_query = null;
select group_concat(`revoke_statement` separator ' ')
into @sub_query
from (
  select concat(
      'REVOKE ', `operations`, ' ON `)" +
            context_.db_name + R"(`.`', `subject`, '` FROM \')" +
            user["name"].get_string() + R"(\';'
  ) as `revoke_statement`
  from )" + Objects::planned_permissions_from_json() +
            R"(
  where
      `user` = ')" +
            user["name"].get_string() + R"(' and
      `type` = 'TABLE' and
      instr(@all_grants, concat('{TABLE:', `subject`, '}')) = 0
  union all
  select concat(
      'REVOKE ', `operations`, ' ON ', `type`, ' `)" +
            context_.db_name + R"(`.`', `subject`, '` FROM \')" +
            user["name"].get_string() + R"(\';'
  ) as `revoke_statement`
  from )" + Objects::planned_permissions_from_json() +
            R"(
  where
      `user` = ')" +
            user["name"].get_string() + R"(' and
      `type` != 'TABLE' and
      instr(@all_grants, concat('{', `type`, ':', `subject`, '}')) = 0
) `extra_grants`;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra permissions for ")" +
            user["name"].get_string() +
            R"(".\';'
,
  @sub_query
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_permissions_from_json() +
            R"(
      where not (
          `user` = ')" +
            user["name"].get_string() +
            R"(' and
          (
              (`type` = 'TABLE' and instr(@all_grants, concat('{TABLE:', `subject`, '}')) = 0) or
              (`type` != 'TABLE' and instr(@all_grants, concat('{', `type`, ':', `subject`, '}')) = 0)
          )
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);
)";

    // Adjust permissions
    for (const auto &permission : user["permissions"].get_array()) {
      const auto type = permission_type(permission);
      std::string grant_operations, revoke_operations;
      auto &permissions = permission["operations"].get_array();
      for (auto operation : permission_operations(type)) {
        if (std::find_if(permissions.begin(), permissions.end(), [&](auto &s) {
              return strcasecmp(s.get_string().c_str(), operation) == 0;
            }) != permissions.end()) {
          if (!grant_operations.empty()) {
            grant_operations += ",";
          }
          grant_operations += operation;
        } else {
          if (!revoke_operations.empty()) {
            revoke_operations += ",";
          }
          revoke_operations += operation;
        }
      }
      sql_ += R"(
set @old_grant = null;
)";
      sql_ += R"(select `operations` into @old_grant
from )" + Objects::planned_permissions_from_json() +
              R"(
where
  `user` = ')" +
              user["name"].get_string() + R"(' and
  `type` = ')" +
              type + R"(' and
  `subject` = ')" +
              permission["subject"].get_string() + R"(';
)";
      if (!grant_operations.empty()) {
        sql_ += R"(
set @qry = if (@old_grant = ')" +
                grant_operations + R"(',
  'SET @r = \'Grant permissions on ")" +
                permission["subject"].get_string() + R"(" for ")" +
                user["name"].get_string() + R"(" is ok.\';'
,
  'GRANT )" + grant_operations +
                R"( ON )" + permission_grant_type(type) + R"(`)" +
                context_.db_name + R"(`.`)" +
                permission["subject"].get_string() + R"(` TO \')" +
                user["name"].get_string() + R"(\';'
);
)";
        sql_ += context_.exec;
      }
      if (!revoke_operations.empty()) {
        sql_ += R"(
set @revoke_operations = '';
)";
        auto &permissions = permission["operations"].get_array();
        for (auto operation : permission_operations(type)) {
          if (std::find_if(permissions.begin(), permissions.end(), [&](auto &s) {
                return strcasecmp(s.get_string().c_str(), operation) == 0;
              }) == permissions.end()) {
            sql_ += R"(
set @revoke_operations = if(find_in_set(')" +
                    std::string{operation} +
                    R"(', ifnull(@old_grant, '')) = 0,
  @revoke_operations,
  if(@revoke_operations = '', ')" +
                    std::string{operation} + R"(', concat(@revoke_operations, ',)" +
                    std::string{operation} + R"('))
);
)";
          }
        }
        sql_ += R"(
set @qry = if (@old_grant = ')" +
                grant_operations + R"(',
  'SET @r = \'Revoke permissions on ")" +
                permission["subject"].get_string() + R"(" for ")" +
                user["name"].get_string() + R"(" is ok.\';'
,
  if(@revoke_operations = '',
    'SET @r = \'No revoke permissions on )" +
                permission["subject"].get_string() + R"( for )" +
                user["name"].get_string() + R"( needed.\';'
  ,
    concat('REVOKE ', @revoke_operations, ' ON )" +
                permission_grant_type(type) + R"(`)" + context_.db_name +
                R"(`.`)" + permission["subject"].get_string() +
                R"(` FROM \')" + user["name"].get_string() + R"(\';')
  )
);
)";
        sql_ += context_.exec;
      }
      sql_ += R"(
set @_sql_permissions = (
  select coalesce(json_arrayagg(json_object(
      'user', `user`,
      'type', `type`,
      'subject', `subject`,
      'operations', `operations`
  )), json_array())
  from (
      select *
      from )" +
              Objects::planned_permissions_from_json() +
              R"(
      where not (
          `user` = ')" +
              user["name"].get_string() +
              R"(' and
          `type` = ')" +
              type +
              R"(' and
          `subject` = ')" +
              permission["subject"].get_string() +
              R"('
      )
      order by `user`, `type`, `subject`
  ) as `_sql_ordered_permissions`
);
)";
      if (!grant_operations.empty()) {
        sql_ += R"(
set @_sql_permissions = json_array_append(@_sql_permissions, '$', json_object(
  'user', ')" + user["name"].get_string() +
                R"(',
  'type', ')" + type +
                R"(',
  'subject', ')" +
                permission["subject"].get_string() +
                R"(',
  'operations', ')" +
                grant_operations + R"('
));
)";
      }
    }
  }
}
std::string Users::snapshot_schema_state(const std::string &db_name) {
  std::string sql;
  sql += R"(
set @_sql_users = (
select coalesce(json_arrayagg(json_object(
    'name', `name`
)), json_array())
from (
    select `USER` as `name`
    from `mysql`.`user`
    order by `USER`
) as `_sql_ordered_users`
);
set @_sql_permissions = (
select coalesce(json_arrayagg(json_object(
    'user', `user`,
    'type', `type`,
    'subject', `subject`,
    'operations', `operations`
)), json_array())
from (
    select
        `user`,
        'TABLE' as `type`,
        `table_name` as `subject`,
        `table_priv` as `operations`
    from `mysql`.`tables_priv`
    where `Db` = ')" +
         db_name + R"('
    union all
    select
        `user`,
        `routine_type` as `type`,
        `routine_name` as `subject`,
        `proc_priv` as `operations`
    from `mysql`.`procs_priv`
    where `Db` = ')" +
         db_name + R"('
    order by `user`, `type`, `subject`
) as `_sql_ordered_permissions`
);
)";
  return sql;
}
