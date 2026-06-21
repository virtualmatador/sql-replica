#include <algorithm>
#include <cctype>
#include <initializer_list>
#include <map>
#include <sstream>
#include <vector>

#include <string.h>

#include "sqlr.h"

void sanitize(const std::string &input, const char *bad_chars) {
  while (*bad_chars) {
    if (input.find(*bad_chars++) != std::string::npos) {
      throw std::runtime_error(input.c_str());
    }
  }
}

namespace {

bool equals_ignore_case(const std::string &lhs, const char *rhs) {
  return strcasecmp(lhs.c_str(), rhs) == 0;
}

void validate_engine(const std::string &engine) {
  if (engine.empty() ||
      std::any_of(engine.begin(), engine.end(), [](unsigned char c) {
        return !std::isalnum(c) && c != '_';
      })) {
    throw std::runtime_error("Publish MySQL: Bad Engine");
  }
}

void validate_key_type(const std::string &type) {
  for (const auto *allowed :
       {"primary key", "unique", "unique key", "unique index", "index", "key",
        "fulltext", "fulltext key", "fulltext index", "spatial",
        "spatial key", "spatial index"}) {
    if (equals_ignore_case(type, allowed)) {
      return;
    }
  }
  throw std::runtime_error("Publish MySQL: Bad Key Type");
}

void validate_foreign_key_action(const std::string &action) {
  for (const auto *allowed :
       {"RESTRICT", "CASCADE", "SET NULL", "NO ACTION", "SET DEFAULT"}) {
    if (equals_ignore_case(action, allowed)) {
      return;
    }
  }
  throw std::runtime_error("Publish MySQL: Bad ForeignKey Action");
}

void validate_fields(const jsonio::json &object,
                     std::initializer_list<const char *> allowed,
                     const char *kind) {
  for (const auto &[key, value] : object.get_object()) {
    if (std::find(allowed.begin(), allowed.end(), key) == allowed.end()) {
      throw std::runtime_error(std::string{"Publish MySQL: Unknown "} + kind +
                               " Field");
    }
  }
}

std::string escape_sql_string(const std::string &input) {
  std::string output;
  for (const auto c : input) {
    if (c == '\\' || c == '\'') {
      output += '\\';
    }
    output += c;
  }
  return output;
}

std::string function_params(const jsonio::json &function) {
  std::string params;
  for (const auto &param : function["params"].get_array()) {
    if (!params.empty()) {
      params += ", ";
    }
    params +=
        "`" + param["name"].get_string() + "` " + param["type"].get_string();
  }
  return params;
}

std::string procedure_params(const jsonio::json &procedure) {
  std::string params;
  for (const auto &param : procedure["params"].get_array()) {
    if (!params.empty()) {
      params += ", ";
    }
    params += param["mode"].get_string() + " `" + param["name"].get_string() +
              "` " + param["type"].get_string();
  }
  return params;
}

const jsonio::json_arr &routine_characteristic_values(
    const jsonio::json &routine) {
  return routine["characteristics"].get_array();
}

std::string routine_characteristics(const jsonio::json &routine) {
  std::string result;
  for (const auto &value : routine_characteristic_values(routine)) {
    if (!result.empty()) {
      result += " ";
    }
    result += value.get_string();
  }
  return result;
}

std::string routine_data_access(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    const auto &text = value.get_string();
    if (strcasecmp(text.c_str(), "CONTAINS SQL") == 0 ||
        strcasecmp(text.c_str(), "NO SQL") == 0 ||
        strcasecmp(text.c_str(), "READS SQL DATA") == 0 ||
        strcasecmp(text.c_str(), "MODIFIES SQL DATA") == 0) {
      return text;
    }
  }
  return "";
}

std::string routine_deterministic(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    const auto &text = value.get_string();
    if (strcasecmp(text.c_str(), "DETERMINISTIC") == 0) {
      return "YES";
    }
    if (strcasecmp(text.c_str(), "NOT DETERMINISTIC") == 0) {
      return "NO";
    }
  }
  return "";
}

std::string routine_security(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    const auto &text = value.get_string();
    if (strncasecmp(text.c_str(), "SQL SECURITY ", 13) == 0) {
      return text.substr(13);
    }
  }
  return "";
}

void validate_routine_characteristics(const jsonio::json &routine) {
  for (const auto &value : routine_characteristic_values(routine)) {
    sanitize(value.get_string(), "\\'`");
  }
}

void validate_function(const jsonio::json &function) {
  validate_fields(function, {"name", "returns", "characteristics", "params",
                             "body"},
                  "Function");
  sanitize(function["name"].get_string(), "\\'`");
  sanitize(function["returns"].get_string(), "\\'`");
  validate_routine_characteristics(function);
  for (const auto &param : function["params"].get_array()) {
    validate_fields(param, {"name", "type"}, "Function Param");
    sanitize(param["name"].get_string(), "\\'`");
    sanitize(param["type"].get_string(), "\\'`");
  }
}

void validate_procedure(const jsonio::json &procedure) {
  validate_fields(procedure, {"name", "characteristics", "params", "body"},
                  "Procedure");
  sanitize(procedure["name"].get_string(), "\\'`");
  validate_routine_characteristics(procedure);
  for (const auto &param : procedure["params"].get_array()) {
    validate_fields(param, {"mode", "name", "type"}, "Procedure Param");
    if (const auto &mode = param["mode"].get_string();
        strcasecmp(mode.c_str(), "IN") != 0 &&
        strcasecmp(mode.c_str(), "OUT") != 0 &&
        strcasecmp(mode.c_str(), "INOUT") != 0) {
      throw std::runtime_error("Publish MySQL: Bad Procedure Param Mode");
    }
    sanitize(param["name"].get_string(), "\\'`");
    sanitize(param["type"].get_string(), "\\'`");
  }
}

std::string permission_type(const jsonio::json &permission) {
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

std::string permission_grant_type(const std::string &type) {
  return type == "TABLE" ? "" : type + " ";
}

std::vector<const char *> permission_operations(const std::string &type) {
  if (type == "TABLE") {
    return {"Select", "Insert", "Update", "Delete"};
  }
  return {"Execute"};
}

} // namespace

std::string
replicate_sql(const std::string &db_name, const jsonio::json &tables,
              const jsonio::json &functions, const jsonio::json &procedures,
              const jsonio::json &users, bool report, bool dry_run) {
  std::string bad_prefix{"_sql_"};
  std::string drop_prefix{"_drop_"};
  sanitize(db_name, "\\'`");
  for (std::map<std::string, std::size_t> table_ids;
       const auto &table : tables.get_array()) {
    validate_fields(table,
                    {"id", "name", "engine", "columns", "keys",
                     "foreign-keys", "views"},
                    "Table");
    sanitize(table["name"].get_string(), "\\'`");
    if (table["name"].get_string().rfind(bad_prefix, 0) == 0) {
      throw std::runtime_error("Publish MySQL: Table Bad Prefix");
    }
    sanitize(table["id"].get_string(), "\\'`");
    if (auto engine = table.get_object().find("engine");
        engine != table.get_object().end()) {
      validate_engine(engine->second.get_string());
    }
    if (++table_ids[table["id"].get_string()] > 1) {
      throw std::runtime_error("Publish MySQL: Repeated Table Id");
    }
    for (std::map<std::string, std::size_t> column_ids;
         const auto &column : table["columns"].get_array()) {
      validate_fields(column, {"id", "name", "type", "auto", "null",
                               "default"},
                      "Column");
      sanitize(column["name"].get_string(), "\\'`");
      if (column["name"].get_string().rfind(bad_prefix, 0) == 0) {
        throw std::runtime_error("Publish MySQL: Column Bad Prefix");
      }
      sanitize(column["type"].get_string(), "\\'`");
      sanitize(column["id"].get_string(), "\\'`");
      if (column["id"].get_string().empty()) {
        throw std::runtime_error("Publish MySQL: Column No Id");
      }
      if (auto default_value = column.at("default"); default_value) {
        sanitize(default_value->get_string(), "\\'`");
      }
      if (++column_ids[column["id"].get_string()] > 1) {
        throw std::runtime_error("Publish MySQL: Repeated Column Id");
      }
    }
    if (auto keys = table.at("keys"); keys) {
      std::map<std::string, std::size_t> index_names;
      for (const auto &key : keys->get_array()) {
        validate_fields(key, {"name", "type", "columns"}, "Key");
        if (key["columns"].get_array().size() == 0) {
          throw std::runtime_error("Publish MySQL: No Key Column");
        }
        for (const auto &clm : key["columns"].get_array()) {
          sanitize(clm.get_string(), "\\'`");
        }
        sanitize(key["name"].get_string(), "\\'`");
        validate_key_type(key["type"].get_string());
        if (++index_names[key["name"].get_string()] > 1) {
          throw std::runtime_error("Publish MySQL: Repeated Key Name");
        }
        if (key["type"].get_string() == "primary key" &&
            key["name"].get_string() != "PRIMARY") {
          throw std::runtime_error("Publish MySQL: Invalid Primary Key Name");
        }
      }
    }
    if (auto foreign_keys = table.at("foreign-keys"); foreign_keys) {
      for (const auto &foreign_key : foreign_keys->get_array()) {
        validate_fields(foreign_key,
                        {"name", "delete", "update", "columns", "table",
                         "keys"},
                        "ForeignKey");
        sanitize(foreign_key["name"].get_string(), "\\'`");
        validate_foreign_key_action(foreign_key["delete"].get_string());
        validate_foreign_key_action(foreign_key["update"].get_string());
        sanitize(foreign_key["table"].get_string(), "\\'`");
        if (foreign_key["columns"].get_array().size() == 0) {
          throw std::runtime_error("Publish MySQL: No ForeignKey Column");
        }
        for (const auto &clm : foreign_key["columns"].get_array()) {
          sanitize(clm.get_string(), "\\'`");
        }
        if (foreign_key["keys"].get_array().size() == 0) {
          throw std::runtime_error("Publish MySQL: No ForeignKey Key");
        }
        for (const auto &clm : foreign_key["keys"].get_array()) {
          sanitize(clm.get_string(), "\\'`");
        }
      }
    }
    if (auto views = table.at("views"); views) {
      for (const auto &view : views->get_array()) {
        validate_fields(view, {"name", "columns", "joints"}, "View");
        sanitize(view["name"].get_string(), "\\'`");
        for (const auto &clm : view["columns"].get_array()) {
          sanitize(clm.get_string(), "\\'`");
        }
        for (const auto &joint : view["joints"].get_array()) {
          validate_fields(joint, {"table", "as", "type", "columns", "ons"},
                          "Joint");
          if (const auto &type = joint["type"].get_string();
              type != "inner" && type != "left outer" &&
              type != "right outer") {
            throw std::runtime_error("Publish MySQL: Bad Join Type");
          }
          sanitize(joint["table"].get_string(), "\\'`");
          sanitize(joint["as"].get_string(), "\\'`");
          for (const auto &on : joint["ons"].get_array()) {
            validate_fields(on, {"foreign", "base"}, "Relation");
            validate_fields(on["base"], {"table", "column"}, "Relation Base");
            sanitize(on["base"]["table"].get_string(), "\\'`");
            sanitize(on["base"]["column"].get_string(), "\\'`");
            sanitize(on["foreign"].get_string(), "\\'`");
          }
          for (const auto &clm : joint["columns"].get_array()) {
            validate_fields(clm, {"name", "as"}, "View Column");
            sanitize(clm["name"].get_string(), "\\'`");
            sanitize(clm["as"].get_string(), "\\'`");
          }
        }
      }
    }
  }
  for (const auto &function : functions.get_array()) {
    validate_function(function);
  }
  for (const auto &procedure : procedures.get_array()) {
    validate_procedure(procedure);
  }
  for (const auto &user : users.get_array()) {
    validate_fields(user, {"name", "permissions"}, "User");
    sanitize(user["name"].get_string(), "\\'`");
    for (const auto &permission : user["permissions"].get_array()) {
      validate_fields(permission, {"type", "subject", "operations"},
                      "Permission");
      sanitize(permission["subject"].get_string(), "\\'`");
      permission_type(permission);
    }
  }

  std::string exec;
  if (report) {
    exec += R"(
select @qry as '';
)";
  }
  if (!dry_run) {
    exec += R"(
prepare stmt from @qry;
execute stmt;
deallocate prepare stmt;
)";
  }

  // Start Transaction
  std::string sql = "";

  // Create database
  sql += R"(
set @old_db = null;
select `SCHEMA_NAME` into @old_db from `INFORMATION_SCHEMA`.`SCHEMATA`
where `SCHEMA_NAME` = ')" +
         db_name + R"(';
set @qry = if (isnull(@old_db),
    'CREATE DATABASE `)" +
         db_name + R"(`;'
,
    'SET @r = \'Database ")" +
         db_name + R"(" exists.\';'
);
)";
  sql += exec;

  // Create tables with prefix
  sql += R"(
set @all_tables = '';
set @all_views = '';
)";
  std::map<std::string, std::string> engines;
  for (const auto &table : tables.get_array()) {
    if (auto engine = table.get_object().find("engine");
        engine != table.get_object().end()) {
      engines[table["name"].get_string()] = engine->second.get_string();
    } else {
      engines[table["name"].get_string()] = "InnoDB";
    }
    sql += R"(
set @all_tables = concat(@all_tables, '{)" +
           table["id"].get_string() + R"(}');
set @old_table = null;
select `TABLE_NAME` into @old_table
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_COMMENT` = ')" +
           table["id"].get_string() + R"(' and
        `TABLE_SCHEMA` = ')" +
           db_name + R"(';
set @qry = if (isnull(@old_table),
    'CREATE TABLE `)" +
           db_name + R"(`.`)" + bad_prefix + table["name"].get_string() +
           R"(` (`)" + bad_prefix + R"(` int UNSIGNED NOT NULL) ENGINE=)" +
           engines[table["name"].get_string()] +
           R"( DEFAULT CHARSET=utf8 COMMENT \')" + table["id"].get_string() +
           R"(\';'
,
    'SET @r = \'Table ")" +
           table["name"].get_string() + R"(" exist.\';'
);
)";
    if (auto views = table.at("views"); views) {
      for (const auto &view : views->get_array()) {
        sql += R"(
set @all_views = concat(@all_views, '{)" +
               view["name"].get_string() + R"(}');
)";
      }
    }
    sql += exec;
  }

  // Remove extra views
  sql += R"(
set @sub_query = null;
select group_concat(concat('`)" +
         db_name + R"(`.`', `TABLE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = ')" +
         db_name +
         R"(' and `TABLE_TYPE` = 'VIEW' and
        instr(@all_views, concat('{', `TABLE_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra view.\';'
,
    concat('DROP VIEW ', @sub_query, ';')
);
)";
  sql += exec;

  // Mark extra tables
  sql += R"(
set @sub_query = null;
select group_concat(concat('`)" +
         db_name + R"(`.`', `TABLE_NAME`, '` to `)" + db_name + R"(`.`)" +
         bad_prefix + drop_prefix +
         R"(', `TABLE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_NAME` not like ')" +
         bad_prefix + drop_prefix + R"(%' and `TABLE_SCHEMA` = ')" + db_name +
         R"(' and `TABLE_TYPE` = 'BASE TABLE' and
        instr(@all_tables, concat('{', `TABLE_COMMENT`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra table.\';'
,
    concat('RENAME TABLE ', @sub_query, ';')
);
)";
  sql += exec;

  // Apply table names
  sql += R"(
set @ren_tables_prefix = '';
set @ren_tables_final = '';
)";
  for (const auto &table : tables.get_array()) {
    sql += R"(
set @old_table = null;
select `TABLE_NAME` into @old_table
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_COMMENT` = ')" +
           table["id"].get_string() + R"(' and
        `TABLE_SCHEMA` = ')" +
           db_name + R"(';
set @ren_tables_prefix = if (@old_table != ')" +
           table["name"].get_string() + R"(' && instr(@old_table, ')" +
           bad_prefix + R"(') != 1,
    concat(@ren_tables_prefix, '`)" +
           db_name + R"(`.`', @old_table, '` to `)" + db_name + R"(`.`)" +
           bad_prefix + table["name"].get_string() + R"(`, ')
,
    @ren_tables_prefix
);
set @ren_tables_final = if (@old_table != ')" +
           table["name"].get_string() +
           R"(',
    concat(@ren_tables_final, '`)" +
           db_name + R"(`.`)" + bad_prefix + table["name"].get_string() +
           R"(` to `)" + db_name + R"(`.`)" + table["name"].get_string() +
           R"(`, ')
,
    @ren_tables_final
);
)";
  }
  sql += R"(
set @qry = if (@ren_tables_final != '',
    if (@ren_tables_prefix != '', concat ('RENAME TABLE ',
        substr(@ren_tables_prefix, 1, length(@ren_tables_prefix) - 2), ';')
    ,
        'SET @r = \'All tables have prefix.\';'
    ),
    'SET @r = \'No table needs prefix.\';'
);
)";
  sql += exec;
  sql += R"(
set @qry = if (@ren_tables_final != '', concat ('RENAME TABLE ',
    substr(@ren_tables_final, 1, length(@ren_tables_final) - 2), ';')
,
    'SET @r = \'No table rename needed.\';');
)";
  sql += exec;

  // Apply table engine
  for (const auto &table : tables.get_array()) {
    sql += R"(
set @old_engine = null;
select `ENGINE` into @old_engine
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_NAME` = ')" +
           table["name"].get_string() + R"(' and
        `TABLE_SCHEMA` = ')" +
           db_name + R"(';
set @qry = if (@old_engine != ')" +
           engines[table["name"].get_string()] + R"(',
    'ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() + R"(` ENGINE=)" +
           engines[table["name"].get_string()] + R"(;'
,
    'SET @r = \'Engine of ")" +
           table["name"].get_string() + R"(" is ok.\';'
);
)";
    sql += exec;
  }

  for (const auto &table : tables.get_array()) {

    // Create columns with prefix
    sql += R"(
set @all_columns = '';
set @sub_query = '';
)";
    for (const auto &column : table["columns"].get_array()) {
      auto default_value = column.at("default");
      sql += R"(
set @all_columns = concat(@all_columns, '{)" +
             column["id"].get_string() +
             R"(}');
set @old_column = null;
select `COLUMN_NAME` into @old_column
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_COMMENT` = ')" +
             column["id"].get_string() + R"(' and
        `COLUMNS`.`TABLE_NAME` = ')" +
             table["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_SCHEMA` = ')" +
             db_name + R"(';
set @sub_query = if (isnull(@old_column),
    concat(@sub_query, 'ADD `)" +
             bad_prefix + column["name"].get_string() + R"(` )" +
             column["type"].get_string() +
             (default_value ? " DEFAULT " + default_value->get_string() : "") +
             R"( COMMENT \')" + column["id"].get_string() +
             R"(\', ')
,
    @sub_query
);
)";
    }
    sql += R"(
set @qry = if (@sub_query != '',
    concat('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() +
           R"(` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
    'SET @r = \'No new column in ")" +
           table["name"].get_string() +
           R"(" is needed.\';'
);
)";
    sql += exec;

    // Mark Extra columns
    sql += R"(
set @sub_query = null;
select group_concat(concat('RENAME COLUMN `', `COLUMN_NAME`, '` to `)" +
           bad_prefix + drop_prefix + R"(', `COLUMN_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_NAME` not like ')" +
           bad_prefix + drop_prefix + R"(%' and `TABLE_SCHEMA` = ')" + db_name +
           R"(' and `TABLE_NAME` = ')" + table["name"].get_string() + R"(' and
        instr(@all_columns, concat('{', `COLUMN_COMMENT`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra column in ")" +
           table["name"].get_string() + R"(".\';'
,
    concat('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() +
           R"(` ', @sub_query, ';')
);
)";
    sql += exec;

    // Apply column names
    sql += R"(
set @ren_columns_prefix = '';
set @ren_columns_final = '';
)";
    for (const auto &column : table["columns"].get_array()) {
      sql += R"(
set @old_column = null;
select `COLUMN_NAME` into @old_column
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_COMMENT` = ')" +
             column["id"].get_string() + R"(' and
        `COLUMNS`.`TABLE_NAME` = ')" +
             table["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_SCHEMA` = ')" +
             db_name + R"(';
set @ren_columns_prefix = if (@old_column != ')" +
             column["name"].get_string() + R"(' && instr(@old_column, ')" +
             bad_prefix + R"(') != 1,
    concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `)" +
             bad_prefix + column["name"].get_string() + R"(`, ')
,
    @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != ')" +
             column["name"].get_string() + R"(',
    concat(@ren_columns_final, 'RENAME COLUMN `)" +
             bad_prefix + column["name"].get_string() + R"(` to `)" +
             column["name"].get_string() + R"(`, ')
,
    @ren_columns_final
);
)";
    }
    sql += R"(
set @qry = if (@ren_columns_final != '',
    if (@ren_columns_prefix != '',
        concat ('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() +
           R"(` ', substr(@ren_columns_prefix, 1,
        length(@ren_columns_prefix) - 2), ';')
    ,
        'SET @r = \'All columns in ")" +
           table["name"].get_string() +
           R"(" have prefix.\';'
    ),
    'SET @r = \'No column in ")" +
           table["name"].get_string() +
           R"(" needs prefix.\';'
);
)";
    sql += exec;
    sql += R"(
set @qry = if (@ren_columns_final != '', concat ('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() + R"(` ',
    substr(@ren_columns_final, 1, length(@ren_columns_final) - 2), ';')
,
    'SET @r = \'No column in ")" +
           table["name"].get_string() +
           R"(" needs rename.\';');
)";
    sql += exec;
  }

  // Drop wrong foreign keys
  std::map<std::string,
           std::map<std::string, std::pair<std::string, std::string>>>
      fk_flatten_columns;
  for (const auto &table : tables.get_array()) {
    sql += R"(
set @all_foreign_keys = '';
)";
    if (auto foreign_keys = table.at("foreign-keys"); foreign_keys) {
      for (const auto &key : foreign_keys->get_array()) {
        std::string key_def;
        for (const auto &clm : key["columns"].get_array()) {
          if (!key_def.empty()) {
            key_def += ", ";
          }
          key_def += '`' + clm.get_string() + '`';
        }
        std::string f_key_def;
        for (const auto &f_key : key["keys"].get_array()) {
          if (!f_key_def.empty()) {
            f_key_def += ", ";
          }
          f_key_def += '`' + f_key.get_string() + '`';
        }
        fk_flatten_columns[table["name"].get_string()]
                          [key["name"].get_string()] = {std::move(key_def),
                                                        std::move(f_key_def)};
        sql += R"(
set @all_foreign_keys = concat(@all_foreign_keys, '{)" +
               key["name"].get_string() + R"(}');
set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
set @old_update_rule = null;
set @old_delete_rule = null;
select
    `fk`.`CONSTRAINT_NAME`,
    `fk`.`TABLE_NAME`,
    `fk`.`key_def`,
    `fk`.`REFERENCED_TABLE_NAME`,
    `fk`.`f_key_def`,
    `rk`.`UPDATE_RULE`,
    `rk`.`DELETE_RULE`
into
    @old_constraint,
    @old_table,
    @old_key_def,
    @old_referenced_table,
    @old_f_key_def,
    @old_update_rule,
    @old_delete_rule
from `INFORMATION_SCHEMA`.`REFERENTIAL_CONSTRAINTS` as `rk`
join (
select
    `CONSTRAINT_NAME`,
    `CONSTRAINT_SCHEMA`,
    `TABLE_NAME`,
    group_concat(concat('`', `COLUMN_NAME`, '`')
        ORDER BY `ORDINAL_POSITION`
        SEPARATOR ', ') as `key_def`,
    `REFERENCED_TABLE_NAME`,
    group_concat(concat('`', `REFERENCED_COLUMN_NAME`, '`')
        ORDER BY `POSITION_IN_UNIQUE_CONSTRAINT`
        SEPARATOR ', ') as `f_key_def`
from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
where
    `REFERENCED_TABLE_NAME` is not null and
    `CONSTRAINT_SCHEMA` = ')" +
               db_name + R"(' and
    `CONSTRAINT_NAME` = ')" +
               key["name"].get_string() + R"('
group by `CONSTRAINT_NAME`, `TABLE_NAME`, `REFERENCED_TABLE_NAME`) as `fk`
using (
    `CONSTRAINT_SCHEMA`,
    `CONSTRAINT_NAME`,
    `TABLE_NAME`,
    `REFERENCED_TABLE_NAME`);
set @old_ok = 
    @old_table = ')" +
               table["name"].get_string() + R"(' and
    @old_key_def = ')" +
               fk_flatten_columns[table["name"].get_string()]
                                 [key["name"].get_string()]
                                     .first +
               R"(' and
    @old_referenced_table = ')" +
               key["table"].get_string() + R"(' and
    @old_f_key_def = ')" +
               fk_flatten_columns[table["name"].get_string()]
                                 [key["name"].get_string()]
                                     .second +
               R"(' and
    @old_update_rule = ')" +
               key["update"].get_string() + R"(' and
    @old_delete_rule = ')" +
               key["delete"].get_string() + R"(';
set @qry = if (@old_ok or isnull(@old_constraint),
    'SET @r = \'Foreign key ")" +
               key["name"].get_string() +
               R"(" does not exist.\';'
,
    concat('ALTER TABLE `)" +
               db_name + R"(`.`', @old_table, '` DROP FOREIGN KEY `)" +
               key["name"].get_string() + R"(`;'));
)";
        sql += exec;
      }
    }

    // Remove extra foreign keys
    sql += R"(
set @sub_query = null;
select group_concat(distinct
    concat('DROP FOREIGN KEY `', `CONSTRAINT_NAME`, '`') SEPARATOR ', ')
into @sub_query
from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
where
    `REFERENCED_TABLE_NAME` is not null and
    `TABLE_SCHEMA` = ')" +
           db_name + R"(' and
    `TABLE_NAME` = ')" +
           table["name"].get_string() + R"(' and
    instr(@all_foreign_keys, concat('{', `CONSTRAINT_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra foreign keys in ")" +
           table["name"].get_string() +
           R"(".\';'
,
    concat('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() +
           R"(` ', @sub_query, ';')
);
)";
    sql += exec;
  }

  for (const auto &table : tables.get_array()) {
    // Apply column properties
    sql += R"(
set @sub_query = '';
set @ordinal_change = false;
)";
    std::string order = "FIRST";
    for (const auto &column : table["columns"].get_array()) {
      auto ordinal_position{std::to_string(
          1 + std::distance(&table["columns"].get_array().front(), &column))};
      auto is_null = false;
      if (auto column_null = column.at("null");
          column_null && column_null->get_bool()) {
        is_null = true;
      }
      auto default_value = column.at("default");
      auto is_auto = false;
      if (auto column_auto = column.at("auto");
          column_auto && column_auto->get_bool()) {
        is_auto = true;
      };
      sql +=
          R"(
set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `COLUMN_TYPE`, `COLUMN_DEFAULT`, `IS_NULLABLE`,
    `EXTRA` like '%auto_increment%' as AUTO, `ORDINAL_POSITION`
    into @old_type, @old_default, @old_null, @old_auto, @old_position
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_NAME` = ')" +
          column["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_NAME` = ')" +
          table["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_SCHEMA` = ')" +
          db_name + R"(';
set @ordinal_change = if (@old_position != )" +
          ordinal_position +
          R"(, true, @ordinal_change);
set @sub_query = if (@ordinal_change or
    @old_type != ')" +
          column["type"].get_string() + R"(')" +
          (default_value ? R"( or @old_default IS NULL or @old_default != )" +
                               default_value->get_string()
                         : "") +
          R"( or
    @old_null != ')" +
          (is_null ? "YES" : "NO") + R"(' or
    @old_auto != )" +
          (is_auto ? "true" : "false") + R"(,
    concat(@sub_query, 'MODIFY `)" +
          column["name"].get_string() + R"(` )" + column["type"].get_string() +
          (default_value ? " DEFAULT " + default_value->get_string() : "") +
          (is_null ? " null" : " not null") +
          (is_auto ? " auto_increment" : "") + R"( COMMENT \')" +
          column["id"].get_string() + R"(\' )" + order +
          R"(, ')
,
    @sub_query
);
)";
      order = "AFTER `" + column["name"].get_string() + "`";
    }

    // Apply keys
    sql += R"(
set @all_keys = '';
)";
    if (auto keys = table.at("keys"); keys) {
      for (const auto &key : keys->get_array()) {
        std::string key_def;
        for (const auto &clm : key["columns"].get_array()) {
          if (!key_def.empty()) {
            key_def += ", ";
          }
          key_def += '`' + clm.get_string() + '`';
        }
        sql += R"(
set @all_keys = concat(@all_keys, '{)" +
               key["name"].get_string() + R"(}');
set @old_index = null;
set @old_key_def = null;
select
    `INDEX_NAME`,
    group_concat(concat('`', `COLUMN_NAME`, '`')
        ORDER BY `SEQ_IN_INDEX` SEPARATOR ', ')
into
    @old_index,
    @old_key_def
from `INFORMATION_SCHEMA`.`STATISTICS`
where
    `TABLE_SCHEMA` = ')" +
               db_name + R"(' and
    `TABLE_NAME` = ')" +
               table["name"].get_string() + R"(' and
    `INDEX_NAME` = ')" +
               key["name"].get_string() + R"('
group by `INDEX_NAME`;
set @old_ok = @old_key_def = ')" +
               key_def + R"(';
set @drop_query = if (@old_ok or isnull(@old_index), '',
    'DROP INDEX `)" +
               key["name"].get_string() + R"(`, ');
set @sub_query = concat(@sub_query, @drop_query);
set @sub_query = if (@drop_query != '' or isnull(@old_index),
    concat(@sub_query, 'ADD )" +
               key["type"].get_string() + R"( `)" + key["name"].get_string() +
               R"(` ()" + key_def + R"(), ')
, @sub_query);
)";
      }
    }

    // Remove extra keys
    sql += R"(
set @drop_query = null;
select group_concat(distinct
    concat('DROP INDEX `', `INDEX_NAME`, '`') SEPARATOR ', ')
into @drop_query
from `INFORMATION_SCHEMA`.`STATISTICS`
join `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
on
    `INFORMATION_SCHEMA`.`STATISTICS`.`INDEX_SCHEMA` =
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`CONSTRAINT_SCHEMA` and
    `INFORMATION_SCHEMA`.`STATISTICS`.`TABLE_NAME` =
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`TABLE_NAME` and
    `INFORMATION_SCHEMA`.`STATISTICS`.`INDEX_NAME` =
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`CONSTRAINT_NAME`
where
    `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`.`REFERENCED_TABLE_NAME` is null and
    `INFORMATION_SCHEMA`.`STATISTICS`.`INDEX_SCHEMA` = ')" +
           db_name + R"(' and
    `INFORMATION_SCHEMA`.`STATISTICS`.`TABLE_NAME` = ')" +
           table["name"].get_string() + R"(' and
    instr(@all_keys, concat('{', `INDEX_NAME`, '}')) = 0;
set @sub_query = if (isnull(@drop_query), @sub_query,
    concat(@sub_query, @drop_query, ', ')
);
)";
    // Remove extra columns
    sql += R"(
set @drop_query = null;
select group_concat(concat('DROP COLUMN `', `COLUMN_NAME`, '`')
    SEPARATOR ', ') into @drop_query
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where
        `COLUMNS`.`TABLE_NAME` = ')" +
           table["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_SCHEMA` = ')" +
           db_name + R"(' and
        `COLUMN_NAME` like ')" +
           bad_prefix + drop_prefix + R"(%';
set @sub_query = if (isnull(@drop_query), @sub_query,
    concat(@sub_query, @drop_query, ', ')
);
)";
    sql += R"(
set @qry = if (@sub_query != '',
    concat ('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() +
           R"(` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
    'SET @r = \'Table ")" +
           table["name"].get_string() + R"(" is ok.\';'
);
)";
    sql += exec;
  }

  for (const auto &table : tables.get_array()) {
    // remove extra defaults
    sql += R"(
set @sub_query = '';
)";
    for (const auto &column : table["columns"].get_array()) {
      if (!column.at("default")) {
        sql +=
            R"(
set @old_default = null;
select `COLUMN_DEFAULT`
    into @old_default
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `COLUMN_NAME` = ')" +
            column["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_NAME` = ')" +
            table["name"].get_string() + R"(' and
        `COLUMNS`.`TABLE_SCHEMA` = ')" +
            db_name + R"(';
set @sub_query = if (@old_default IS NOT NULL,
    concat(@sub_query, 'ALTER COLUMN `)" +
            column["name"].get_string() + R"(` DROP DEFAULT, ')
,
    @sub_query
);
)";
      }
    }

    sql += R"(
set @qry = if (@sub_query != '',
    concat ('ALTER TABLE `)" +
           db_name + R"(`.`)" + table["name"].get_string() +
           R"(` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
    'SET @r = \'Table ")" +
           table["name"].get_string() + R"(" is ok.\';'
);
)";
    sql += exec;
  }

  // Remove extra tables
  sql += R"(
set @sub_query = null;
select group_concat(concat('`)" +
         db_name + R"(`.`', `TABLE_NAME`, '`')
    SEPARATOR ', ') into @sub_query
from `INFORMATION_SCHEMA`.`TABLES`
where
    `TABLE_SCHEMA` = ')" +
         db_name + R"(' and
    `TABLE_NAME` like ')" +
         bad_prefix + drop_prefix + R"(%';
set @qry = if (isnull(@sub_query), 'SET @r = \'No extra table.\';',
    concat('DROP TABLE ', @sub_query, ';')
);
)";
  sql += exec;

  // Create foreign keys
  for (const auto &table : tables.get_array()) {
    if (auto foreign_keys = table.at("foreign-keys"); foreign_keys) {
      for (const auto &key : foreign_keys->get_array()) {
        sql += R"(
set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
select `CONSTRAINT_NAME` into @old_constraint
from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
where
    `REFERENCED_TABLE_NAME` is not null and
    `TABLE_SCHEMA` = ')" +
               db_name + R"(' and
    `TABLE_NAME` = ')" +
               table["name"].get_string() + R"(' and
    `CONSTRAINT_NAME` = ')" +
               key["name"].get_string() + R"('
group by `CONSTRAINT_NAME`, `TABLE_NAME`;
set @create_query = if (isnull(@old_constraint),
    concat('ALTER TABLE `)" +
               db_name + R"(`.`)" + table["name"].get_string() +
               R"(` ADD CONSTRAINT `)" + key["name"].get_string() +
               R"(` FOREIGN KEY ()" +
               fk_flatten_columns[table["name"].get_string()]
                                 [key["name"].get_string()]
                                     .first +
               R"() REFERENCES `)" + db_name + R"(`.`)" +
               key["table"].get_string() + R"(` ()" +
               fk_flatten_columns[table["name"].get_string()]
                                 [key["name"].get_string()]
                                     .second +
               R"() ON UPDATE )" + key["update"].get_string() +
               R"( ON DELETE )" + key["delete"].get_string() + R"(;')
    , '');
set @qry = if (@create_query != '', @create_query,
    'SET @r = \'Foreign key ")" +
               key["name"].get_string() + R"(" is ok.\';');
)";
        sql += exec;
      }
    }
  }

  // Create views
  for (const auto &table : tables.get_array()) {
    if (auto views = table.at("views"); views) {
      for (const auto &view : views->get_array()) {
        sql += R"(
set @qry = 'CREATE OR REPLACE VIEW `)" +
               db_name + R"(`.`)" + view["name"].get_string() + R"(` AS SELECT
)";
        std::string columns;
        for (const auto &clm : view["columns"].get_array()) {
          if (!columns.empty()) {
            columns += ", ";
          }
          columns +=
              "`" + table["name"].get_string() + "`.`" + clm.get_string() + "`";
        }
        std::string from = R"( FROM `)" + db_name + R"(`.`)" +
                           table["name"].get_string() + R"(` )";
        for (const auto &joint : view["joints"].get_array()) {
          from += joint["type"].get_string() + R"( join `)" + db_name +
                  R"(`.`)" + joint["table"].get_string() + R"(` AS `)" +
                  joint["as"].get_string() + R"(` ON )";
          std::string ons;
          for (const auto &on : joint["ons"].get_array()) {
            if (!ons.empty()) {
              ons += "AND ";
            }
            ons += R"(`)" + db_name + R"(`.`)" +
                   on["base"]["table"].get_string() + R"(`.`)" +
                   on["base"]["column"].get_string() + R"(` = `)" + db_name +
                   R"(`.`)" + joint["as"].get_string() + R"(`.`)" +
                   on["foreign"].get_string() + R"(` )";
          }
          from += ons;
          for (const auto &clm : joint["columns"].get_array()) {
            if (!columns.empty()) {
              columns += ", ";
            }
            columns += R"(`)" + db_name + R"(`.`)" + joint["as"].get_string() +
                       R"(`.`)" + clm["name"].get_string() + R"(` AS `)" +
                       clm["as"].get_string() + "`";
          }
        }
        sql += columns + from + R"(;';)";
        sql += exec;
      }
    }
  }

  // Remove extra functions
  sql += R"(
set @all_functions = '';
)";
  for (const auto &function : functions.get_array()) {
    sql += R"(
set @all_functions = concat(@all_functions, '{)" +
           function["name"].get_string() + R"(}');
)";
  }
  sql += R"(
set @sub_query = null;
select group_concat(concat('`)" +
         db_name + R"(`.`', `ROUTINE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = ')" +
         db_name + R"(' and `ROUTINE_TYPE` = 'FUNCTION' and
        instr(@all_functions, concat('{', `ROUTINE_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra function.\';'
,
    concat('DROP FUNCTION ', @sub_query, ';')
);
)";
  sql += exec;

  // Apply functions
  if (functions.get_array().size() != 0) {
    sql += R"(
set @function_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));
)";
  }
  for (const auto &function : functions.get_array()) {
    const auto characteristics = routine_characteristics(function);
    const auto data_access = routine_data_access(function);
    const auto deterministic = routine_deterministic(function);
    const auto security = routine_security(function);
    sql += R"(
set @old_body = null;
set @old_returns = null;
set @old_data_access = null;
set @old_deterministic = null;
set @old_security = null;
set @old_params = null;
select `ROUTINE_DEFINITION`, `DTD_IDENTIFIER`, `SQL_DATA_ACCESS`,
        `IS_DETERMINISTIC`, `SECURITY_TYPE`
    into @old_body, @old_returns, @old_data_access, @old_deterministic,
        @old_security
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = ')" +
           db_name + R"(' and
        `ROUTINE_TYPE` = 'FUNCTION' and
        `ROUTINE_NAME` = ')" +
           function["name"].get_string() + R"(';
set @old_body = trim(@old_body);
set @old_body = if (
    upper(left(@old_body, 5)) = 'BEGIN' and upper(right(@old_body, 3)) = 'END',
    trim(substr(@old_body, 6, length(@old_body) - 8)),
    @old_body
);
select group_concat(concat('`', `PARAMETER_NAME`, '` ', `DTD_IDENTIFIER`)
        ORDER BY `ORDINAL_POSITION` SEPARATOR ', ')
    into @old_params
    from `INFORMATION_SCHEMA`.`PARAMETERS`
    where `SPECIFIC_SCHEMA` = ')" +
           db_name + R"(' and
        `ROUTINE_TYPE` = 'FUNCTION' and
        `SPECIFIC_NAME` = ')" +
           function["name"].get_string() + R"(' and
        `PARAMETER_NAME` is not null;
set @function_changed =
    isnull(@old_body) or
    @old_body != ')" +
           escape_sql_string(function["body"].get_string()) + R"(' or
    ifnull(@old_returns, '') != ')" +
           function["returns"].get_string() + R"(' or
)" +
           (data_access.empty() ? "" : R"(    ifnull(@old_data_access, '') != ')" +
                                       data_access + R"(' or
)") +
           (deterministic.empty() ? "" : R"(    ifnull(@old_deterministic, '') != ')" +
                                        deterministic + R"(' or
)") +
           (security.empty() ? "" : R"(    ifnull(@old_security, '') != ')" +
                                   security + R"(' or
)") +
           R"(
    ifnull(@old_params, '') != ')" +
           function_params(function) + R"(';
set @qry = if (@function_changed,
    'DROP FUNCTION IF EXISTS `)" +
           db_name + R"(`.`)" + function["name"].get_string() + R"(`;'
,
    'SET @r = \'Function Drop )" +
           function["name"].get_string() + R"( is ok.\';'
);
)";
    sql += exec;
    sql += R"(
set @qry = if (@function_changed,
    concat('DELIMITER ', @function_delimiter, '\n', 'CREATE FUNCTION `)" +
           db_name + R"(`.`)" + function["name"].get_string() + R"(`()" +
           function_params(function) + R"() RETURNS )" +
           function["returns"].get_string() + " " +
           (characteristics.empty() ? "" : characteristics + " ") + R"(BEGIN )" +
           escape_sql_string(function["body"].get_string()) +
           R"( END ', @function_delimiter, '\n', 'DELIMITER ;')
,
    'SET @r = \'Function Create )" +
           function["name"].get_string() + R"( is ok.\';'
);
)";
    sql += exec;
  }

  // Remove extra procedures
  sql += R"(
set @all_procedures = '';
)";
  for (const auto &procedure : procedures.get_array()) {
    sql += R"(
set @all_procedures = concat(@all_procedures, '{)" +
           procedure["name"].get_string() + R"(}');
)";
  }
  sql += R"(
set @sub_query = null;
select group_concat(concat('`)" +
         db_name + R"(`.`', `ROUTINE_NAME`, '`') SEPARATOR ', ')
    into @sub_query
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = ')" +
         db_name + R"(' and `ROUTINE_TYPE` = 'PROCEDURE' and
        instr(@all_procedures, concat('{', `ROUTINE_NAME`, '}')) = 0;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra procedure.\';'
,
    concat('DROP PROCEDURE ', @sub_query, ';')
);
)";
  sql += exec;

  // Apply procedures
  if (procedures.get_array().size() != 0) {
    sql += R"(
set @procedure_delimiter = concat('d', left(replace(uuid(), '-', ''), 13));
)";
  }
  for (const auto &procedure : procedures.get_array()) {
    const auto characteristics = routine_characteristics(procedure);
    const auto data_access = routine_data_access(procedure);
    const auto deterministic = routine_deterministic(procedure);
    const auto security = routine_security(procedure);
    sql += R"(
set @old_body = null;
set @old_data_access = null;
set @old_deterministic = null;
set @old_security = null;
set @old_params = null;
select `ROUTINE_DEFINITION`, `SQL_DATA_ACCESS`, `IS_DETERMINISTIC`,
        `SECURITY_TYPE`
    into @old_body, @old_data_access, @old_deterministic, @old_security
    from `INFORMATION_SCHEMA`.`ROUTINES`
    where `ROUTINE_SCHEMA` = ')" +
           db_name + R"(' and
        `ROUTINE_TYPE` = 'PROCEDURE' and
        `ROUTINE_NAME` = ')" +
           procedure["name"].get_string() + R"(';
set @old_body = trim(@old_body);
set @old_body = if (
    upper(left(@old_body, 5)) = 'BEGIN' and upper(right(@old_body, 3)) = 'END',
    trim(substr(@old_body, 6, length(@old_body) - 8)),
    @old_body
);
select group_concat(concat(`PARAMETER_MODE`, ' `', `PARAMETER_NAME`, '` ',
        `DTD_IDENTIFIER`) ORDER BY `ORDINAL_POSITION` SEPARATOR ', ')
    into @old_params
    from `INFORMATION_SCHEMA`.`PARAMETERS`
    where `SPECIFIC_SCHEMA` = ')" +
           db_name + R"(' and
        `ROUTINE_TYPE` = 'PROCEDURE' and
        `SPECIFIC_NAME` = ')" +
           procedure["name"].get_string() + R"(' and
        `PARAMETER_NAME` is not null;
set @procedure_changed =
    isnull(@old_body) or
    @old_body != ')" +
           escape_sql_string(procedure["body"].get_string()) + R"(' or
)" +
           (data_access.empty() ? "" : R"(    ifnull(@old_data_access, '') != ')" +
                                       data_access + R"(' or
)") +
           (deterministic.empty() ? "" : R"(    ifnull(@old_deterministic, '') != ')" +
                                        deterministic + R"(' or
)") +
           (security.empty() ? "" : R"(    ifnull(@old_security, '') != ')" +
                                   security + R"(' or
)") +
           R"(
    ifnull(@old_params, '') != ')" +
           procedure_params(procedure) + R"(';
set @qry = if (@procedure_changed,
    'DROP PROCEDURE IF EXISTS `)" +
           db_name + R"(`.`)" + procedure["name"].get_string() + R"(`;'
,
    'SET @r = \'Procedure )" +
           procedure["name"].get_string() + R"( is ok.\';'
);
)";
    sql += exec;
    sql += R"(
set @qry = if (@procedure_changed,
    concat('DELIMITER ', @procedure_delimiter, '\n', 'CREATE PROCEDURE `)" +
           db_name + R"(`.`)" + procedure["name"].get_string() + R"(`()" +
           procedure_params(procedure) + R"() )" +
           (characteristics.empty() ? "" : characteristics + " ") + R"(BEGIN )" +
           escape_sql_string(procedure["body"].get_string()) +
           R"( END ', @procedure_delimiter, '\n', 'DELIMITER ;')
,
    'SET @r = \'Procedure )" +
           procedure["name"].get_string() + R"( is ok.\';'
);
)";
    sql += exec;
  }

  // Apply users
  std::size_t index = 0;
  for (const auto &user : users.get_array()) {
    sql += R"(
set @old_user = null;
select `USER` into @old_user from `mysql`.`user`
where `USER` = ')" +
           user["name"].get_string() + R"(';
set @qry = if (isnull(@old_user),
    concat('CREATE USER \')" +
           user["name"].get_string() +
           R"(\' ACCOUNT LOCK;')
,
    'SET @r = \'User ")" +
           user["name"].get_string() + R"(" exists.\';'
);
)";
    sql += exec;
    sql += "set @all_grants = '';";
    // Revoke permissions of extra subjects
    for (const auto &permission : user["permissions"].get_array()) {
      sql += "\nset @all_grants = concat(@all_grants, '{";
      sql += permission_type(permission);
      sql += ":";
      sql += permission["subject"].get_string();
      sql += "}');";
    }
    sql += R"(
set @sub_query = null;
select group_concat(`grant_name` separator ', ')
into @sub_query
from (
    select concat('`', `table_name`, '`') as `grant_name`
    from `mysql`.`tables_priv`
    where
        `Db` = ')" +
           db_name + R"(' and
        `user` = ')" +
           user["name"].get_string() + R"(' and
        instr(@all_grants, concat('{TABLE:', `table_name`, '}')) = 0
    union all
    select concat(`routine_type`, ' `', `routine_name`, '`') as `grant_name`
    from `mysql`.`procs_priv`
    where
        `Db` = ')" +
           db_name + R"(' and
        `user` = ')" +
           user["name"].get_string() + R"(' and
        instr(@all_grants, concat('{', `routine_type`, ':', `routine_name`, '}')) = 0
) `extra_grants`;
set @qry = if (isnull(@sub_query),
    'SET @r = \'No extra permissions for ")" +
           user["name"].get_string() +
           R"(".\';'
,
    'REVOKE IF EXISTS SELECT, INSERT, UPDATE, DELETE, EXECUTE ON `)" +
           db_name + R"(`.* FROM \')" + user["name"].get_string() +
           R"(\';'
);
)";
    sql += exec;

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
      sql += R"(
set @old_grant = null;
)";
      if (type == "TABLE") {
        sql += R"(select `table_priv` into @old_grant
from `mysql`.`tables_priv`
where
    `Db` = ')" +
             db_name + R"(' and
    `user` = ')" +
             user["name"].get_string() + R"(' and
    `table_name` = ')" +
             permission["subject"].get_string() + R"(';
)";
      } else {
        sql += R"(select `proc_priv` into @old_grant
from `mysql`.`procs_priv`
where
    `Db` = ')" +
             db_name + R"(' and
    `user` = ')" +
             user["name"].get_string() + R"(' and
    `routine_type` = ')" +
             type + R"(' and
    `routine_name` = ')" +
             permission["subject"].get_string() + R"(';
)";
      }
      if (!grant_operations.empty()) {
        sql += R"(
set @qry = if (@old_grant = ')" +
               grant_operations + R"(',
    'SET @r = \'Grant permissions on ")" +
               permission["subject"].get_string() + R"(" for ")" +
               user["name"].get_string() + R"(" is ok.\';'
,
    'GRANT )" + grant_operations +
               R"( ON )" + permission_grant_type(type) + R"(`)" + db_name +
               R"(`.`)" +
               permission["subject"].get_string() + R"(` TO \')" +
               user["name"].get_string() + R"(\';'
);
)";
        sql += exec;
      }
      if (!revoke_operations.empty()) {
        sql += R"(
set @qry = if (@old_grant = ')" +
               grant_operations + R"(',
    'SET @r = \'Revoke permissions on ")" +
               permission["subject"].get_string() + R"(" for ")" +
               user["name"].get_string() + R"(" is ok.\';'
,
    'REVOKE IF EXISTS )" +
               revoke_operations + R"( ON )" + permission_grant_type(type) +
               R"(`)" + db_name + R"(`.`)" +
               permission["subject"].get_string() + R"(` FROM \')" +
               user["name"].get_string() + R"(\';'
);
)";
        sql += exec;
      }
    }
  }

  return sql;
}
