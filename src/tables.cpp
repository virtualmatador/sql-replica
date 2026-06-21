#include "tables.h"

#include "objects.h"

#include <algorithm>
#include <cctype>
#include <map>
#include <string.h>
#include <utility>

void Tables::validate_engine(const std::string &engine) {
  if (engine.empty() ||
      std::any_of(engine.begin(), engine.end(), [](unsigned char c) {
        return !std::isalnum(c) && c != '_';
      })) {
    throw std::runtime_error("Publish MySQL: Bad Engine");
  }
}

void Tables::validate_key_type(const std::string &type) {
  for (const auto *allowed :
       {"primary key", "unique", "unique key", "unique index", "index", "key",
        "fulltext", "fulltext key", "fulltext index", "spatial", "spatial key",
        "spatial index"}) {
    if (Objects::equals_ignore_case(type, allowed)) {
      return;
    }
  }
  throw std::runtime_error("Publish MySQL: Bad Key Type");
}

void Tables::validate_foreign_key_action(const std::string &action) {
  for (const auto *allowed :
       {"RESTRICT", "CASCADE", "SET NULL", "NO ACTION", "SET DEFAULT"}) {
    if (Objects::equals_ignore_case(action, allowed)) {
      return;
    }
  }
  throw std::runtime_error("Publish MySQL: Bad ForeignKey Action");
}

void Tables::validate(const jsonio::json &tables,
                      const std::string &bad_prefix) {
  for (std::map<std::string, std::size_t> table_ids;
       const auto &table : tables.get_array()) {
    Objects::validate_fields(
        table,
        {"id", "name", "engine", "columns", "keys", "foreign-keys", "views"},
        "Table");
    Objects::sanitize(table["name"].get_string(), "\\'`");
    if (table["name"].get_string().rfind(bad_prefix, 0) == 0) {
      throw std::runtime_error("Publish MySQL: Table Bad Prefix");
    }
    Objects::sanitize(table["id"].get_string(), "\\'`");
    if (auto engine = table.get_object().find("engine");
        engine != table.get_object().end()) {
      validate_engine(engine->second.get_string());
    }
    if (++table_ids[table["id"].get_string()] > 1) {
      throw std::runtime_error("Publish MySQL: Repeated Table Id");
    }
    for (std::map<std::string, std::size_t> column_ids;
         const auto &column : table["columns"].get_array()) {
      Objects::validate_fields(
          column, {"id", "name", "type", "auto", "null", "default"}, "Column");
      Objects::sanitize(column["name"].get_string(), "\\'`");
      if (column["name"].get_string().rfind(bad_prefix, 0) == 0) {
        throw std::runtime_error("Publish MySQL: Column Bad Prefix");
      }
      Objects::sanitize(column["type"].get_string(), "\\'`");
      Objects::sanitize(column["id"].get_string(), "\\'`");
      if (column["id"].get_string().empty()) {
        throw std::runtime_error("Publish MySQL: Column No Id");
      }
      if (auto default_value = column.at("default"); default_value) {
        Objects::sanitize(default_value->get_string(), "\\'`");
      }
      if (++column_ids[column["id"].get_string()] > 1) {
        throw std::runtime_error("Publish MySQL: Repeated Column Id");
      }
    }
    if (auto keys = table.at("keys"); keys) {
      std::map<std::string, std::size_t> index_names;
      for (const auto &key : keys->get_array()) {
        Objects::validate_fields(key, {"name", "type", "columns"}, "Key");
        if (key["columns"].get_array().size() == 0) {
          throw std::runtime_error("Publish MySQL: No Key Column");
        }
        for (const auto &clm : key["columns"].get_array()) {
          Objects::sanitize(clm.get_string(), "\\'`");
        }
        Objects::sanitize(key["name"].get_string(), "\\'`");
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
        Objects::validate_fields(
            foreign_key,
            {"name", "delete", "update", "columns", "table", "keys"},
            "ForeignKey");
        Objects::sanitize(foreign_key["name"].get_string(), "\\'`");
        validate_foreign_key_action(foreign_key["delete"].get_string());
        validate_foreign_key_action(foreign_key["update"].get_string());
        Objects::sanitize(foreign_key["table"].get_string(), "\\'`");
        if (foreign_key["columns"].get_array().size() == 0) {
          throw std::runtime_error("Publish MySQL: No ForeignKey Column");
        }
        for (const auto &clm : foreign_key["columns"].get_array()) {
          Objects::sanitize(clm.get_string(), "\\'`");
        }
        if (foreign_key["keys"].get_array().size() == 0) {
          throw std::runtime_error("Publish MySQL: No ForeignKey Key");
        }
        for (const auto &clm : foreign_key["keys"].get_array()) {
          Objects::sanitize(clm.get_string(), "\\'`");
        }
      }
    }
    if (auto views = table.at("views"); views) {
      for (const auto &view : views->get_array()) {
        Objects::validate_fields(view, {"name", "columns", "joints"}, "View");
        Objects::sanitize(view["name"].get_string(), "\\'`");
        for (const auto &clm : view["columns"].get_array()) {
          Objects::sanitize(clm.get_string(), "\\'`");
        }
        for (const auto &joint : view["joints"].get_array()) {
          Objects::validate_fields(
              joint, {"table", "as", "type", "columns", "ons"}, "Joint");
          if (const auto &type = joint["type"].get_string();
              type != "inner" && type != "left outer" &&
              type != "right outer") {
            throw std::runtime_error("Publish MySQL: Bad Join Type");
          }
          Objects::sanitize(joint["table"].get_string(), "\\'`");
          Objects::sanitize(joint["as"].get_string(), "\\'`");
          for (const auto &on : joint["ons"].get_array()) {
            Objects::validate_fields(on, {"foreign", "base"}, "Relation");
            Objects::validate_fields(on["base"], {"table", "column"},
                                     "Relation Base");
            Objects::sanitize(on["base"]["table"].get_string(), "\\'`");
            Objects::sanitize(on["base"]["column"].get_string(), "\\'`");
            Objects::sanitize(on["foreign"].get_string(), "\\'`");
          }
          for (const auto &clm : joint["columns"].get_array()) {
            Objects::validate_fields(clm, {"name", "as"}, "View Column");
            Objects::sanitize(clm["name"].get_string(), "\\'`");
            Objects::sanitize(clm["as"].get_string(), "\\'`");
          }
        }
      }
    }
  }
}

std::string Tables::generate(const jsonio::json &tables,
                             const Context &context) {
  return Tables{tables, context}.generate();
}

Tables::Tables(const jsonio::json &tables, const Context &context)
    : tables_(tables), context_(context) {}

std::string Tables::generate() {
  create_tables_with_prefix();
  remove_extra_views();
  mark_extra_tables();
  apply_table_names();
  apply_table_engine();
  apply_columns_and_keys();
  drop_wrong_foreign_keys();
  apply_column_properties();
  remove_extra_defaults();
  remove_extra_tables();
  create_foreign_keys();
  create_views();
  return sql_;
}

void Tables::create_tables_with_prefix() {
  // Create tables with prefix
  sql_ += R"(
set @all_tables = '';
set @all_views = '';
)";
  for (const auto &table : tables_.get_array()) {
    if (auto engine = table.get_object().find("engine");
        engine != table.get_object().end()) {
      engines_[table["name"].get_string()] = engine->second.get_string();
    } else {
      engines_[table["name"].get_string()] = "InnoDB";
    }
    sql_ += R"(
set @all_tables = concat(@all_tables, '{)" +
            table["id"].get_string() + R"(}');
set @old_table = null;
select `name` into @old_table
  from )" + Objects::planned_tables_from_json() +
            R"(
  where `comment` = ')" +
            table["id"].get_string() + R"(' and `type` = 'BASE TABLE';
set @qry = if (isnull(@old_table),
  'CREATE TABLE `)" +
            context_.db_name + R"(`.`)" + context_.bad_prefix +
            table["name"].get_string() + R"(` (`)" + context_.bad_prefix +
            R"(` int UNSIGNED NOT NULL) ENGINE=)" +
            engines_[table["name"].get_string()] +
            R"( DEFAULT CHARSET=utf8 COMMENT \')" + table["id"].get_string() +
            R"(\';'
,
  'SET @r = \'Table ")" +
            table["name"].get_string() + R"(" exist.\';'
);
)";
    if (auto views = table.at("views"); views) {
      for (const auto &view : views->get_array()) {
        sql_ += R"(
set @all_views = concat(@all_views, '{)" +
                view["name"].get_string() + R"(}');
)";
      }
    }
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_tables = if(isnull(@old_table),
  json_array_append(@_sql_tables, '$', json_object(
      'name', ')" +
            context_.bad_prefix + table["name"].get_string() +
            R"(',
      'comment', ')" +
            table["id"].get_string() +
            R"(',
      'type', 'BASE TABLE',
      'engine', ')" +
            engines_[table["name"].get_string()] + R"('
  )),
  @_sql_tables
);
)";
  }
}

void Tables::remove_extra_views() {
  // Remove extra views
  sql_ += R"(
set @sub_query = null;
select group_concat(concat('`)" +
          context_.db_name + R"(`.`', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from )" +
          Objects::planned_views_from_json() +
          R"(
  where instr(@all_views, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra view.\';'
,
  concat('DROP VIEW ', @sub_query, ';')
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_views = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_views_from_json() +
          R"(
      where instr(@all_views, concat('{', `name`, '}')) != 0
      order by `name`
  ) as `_sql_ordered_views`
);
)";
}

void Tables::mark_extra_tables() {
  // Mark extra tables
  sql_ += R"(
set @sub_query = null;
select group_concat(concat('`)" +
          context_.db_name + R"(`.`', `name`, '` to `)" + context_.db_name +
          R"(`.`)" + context_.bad_prefix + context_.drop_prefix +
          R"(', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from )" +
          Objects::planned_tables_from_json() +
          R"(
  where `name` not like ')" +
          context_.bad_prefix + context_.drop_prefix +
          R"(%' and `type` = 'BASE TABLE' and
      instr(@all_tables, concat('{', `comment`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra table.\';'
,
  concat('RENAME TABLE ', @sub_query, ';')
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_tables = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'engine', `engine`
  )), json_array())
  from (
      select
          if(`name` not like ')" +
          context_.bad_prefix + context_.drop_prefix +
          R"(%' and `type` = 'BASE TABLE' and
              instr(@all_tables, concat('{', `comment`, '}')) = 0,
              concat(')" +
          context_.bad_prefix + context_.drop_prefix +
          R"(', `name`),
              `name`
          ) as `name`,
          `comment`,
          `type`,
          `engine`
      from )" +
          Objects::planned_tables_from_json() +
          R"(
      order by `type`, `name`
  ) as `_sql_ordered_tables`
);
)";
}

void Tables::apply_table_names() {
  // Apply table names
  sql_ += R"(
set @ren_tables_prefix = '';
set @ren_tables_final = '';
)";
  for (const auto &table : tables_.get_array()) {
    sql_ += R"(
set @old_table = null;
select `name` into @old_table
  from )" + Objects::planned_tables_from_json() +
            R"(
  where `comment` = ')" +
            table["id"].get_string() + R"(' and `type` = 'BASE TABLE';
set @ren_tables_prefix = if (@old_table != ')" +
            table["name"].get_string() + R"(' && instr(@old_table, ')" +
            context_.bad_prefix + R"(') != 1,
  concat(@ren_tables_prefix, '`)" +
            context_.db_name + R"(`.`', @old_table, '` to `)" +
            context_.db_name + R"(`.`)" + context_.bad_prefix +
            table["name"].get_string() + R"(`, ')
,
  @ren_tables_prefix
);
set @ren_tables_final = if (@old_table != ')" +
            table["name"].get_string() +
            R"(',
  concat(@ren_tables_final, '`)" +
            context_.db_name + R"(`.`)" + context_.bad_prefix +
            table["name"].get_string() + R"(` to `)" + context_.db_name +
            R"(`.`)" + table["name"].get_string() +
            R"(`, ')
,
  @ren_tables_final
);
)";
  }
  sql_ += R"(
set @qry = if (@ren_tables_final != '',
  if (@ren_tables_prefix != '', concat ('RENAME TABLE ',
      substr(@ren_tables_prefix, 1, length(@ren_tables_prefix) - 2), ';')
  ,
      'SET @r = \'All tables have prefix.\';'
  ),
  'SET @r = \'No table needs prefix.\';'
);
)";
  sql_ += context_.exec;
  for (const auto &table : tables_.get_array()) {
    sql_ += R"(
set @old_table = null;
select `name` into @old_table
  from )" + Objects::planned_tables_from_json() +
            R"(
  where `comment` = ')" +
            table["id"].get_string() + R"(' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != ')" +
            table["name"].get_string() + R"(' and instr(@old_table, ')" +
            context_.bad_prefix + R"(') != 1, ')" + context_.bad_prefix +
            table["name"].get_string() + R"(', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', ')" +
            table["id"].get_string() + R"(', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_columns_from_json() +
            R"(
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_indexes_from_json() +
            R"(
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_foreign_keys_from_json() +
            R"(
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));
)";
  }
  sql_ += R"(
set @qry = if (@ren_tables_final != '', concat ('RENAME TABLE ',
  substr(@ren_tables_final, 1, length(@ren_tables_final) - 2), ';')
,
  'SET @r = \'No table rename needed.\';');
)";
  sql_ += context_.exec;
  for (const auto &table : tables_.get_array()) {
    sql_ += R"(
set @old_table = null;
select `name` into @old_table
  from )" + Objects::planned_tables_from_json() +
            R"(
  where `comment` = ')" +
            table["id"].get_string() + R"(' and `type` = 'BASE TABLE';
set @new_table = if(@old_table != ')" +
            table["name"].get_string() + R"(', ')" +
            table["name"].get_string() +
            R"(', @old_table);
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', ')" +
            table["id"].get_string() + R"(', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @new_table = @old_table,
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.name'), @new_table)
);
set @_sql_columns = if(@new_table = @old_table, @_sql_columns, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_columns_from_json() +
            R"(
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
));
set @_sql_indexes = if(@new_table = @old_table, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_indexes_from_json() +
            R"(
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_table = @old_table, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', if(`table` = @old_table, @new_table, `table`),
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', if(`referenced_table` = @old_table, @new_table, `referenced_table`),
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_foreign_keys_from_json() +
            R"(
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));
)";
  }
}

void Tables::apply_table_engine() {
  // Apply table engine
  for (const auto &table : tables_.get_array()) {
    sql_ += R"(
set @old_engine = null;
select `engine` into @old_engine
  from )" + Objects::planned_tables_from_json() +
            R"(
  where `name` = ')" +
            table["name"].get_string() + R"(' and `type` = 'BASE TABLE';
set @qry = if (@old_engine != ')" +
            engines_[table["name"].get_string()] + R"(',
  'ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
            R"(` ENGINE=)" + engines_[table["name"].get_string()] + R"(;'
,
  'SET @r = \'Engine of ")" +
            table["name"].get_string() + R"(" is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @table_path = json_unquote(json_search(
  @_sql_tables, 'one', ')" +
            table["id"].get_string() + R"(', null, '$[*].comment'));
set @table_object = if(@table_path is null, null, replace(@table_path, '.comment', ''));
set @_sql_tables = if(@table_object is null or @old_engine = ')" +
            engines_[table["name"].get_string()] + R"(',
  @_sql_tables,
  json_set(@_sql_tables, concat(@table_object, '.engine'), ')" +
            engines_[table["name"].get_string()] + R"(')
);
)";
  }
}

void Tables::apply_columns_and_keys() {
  for (const auto &table : tables_.get_array()) {

    // Create columns with prefix
    sql_ += R"(
set @all_columns = '';
set @sub_query = '';
)";
    for (const auto &column : table["columns"].get_array()) {
      auto default_value = column.at("default");
      sql_ += R"(
set @all_columns = concat(@all_columns, '{)" +
              column["id"].get_string() +
              R"(}');
set @old_column = null;
select `name` into @old_column
  from )" + Objects::planned_columns_from_json() +
              R"(
  where `comment` = ')" +
              column["id"].get_string() + R"(' and
      `table` = ')" +
              table["name"].get_string() + R"(';
set @sub_query = if (isnull(@old_column),
  concat(@sub_query, 'ADD `)" +
              context_.bad_prefix + column["name"].get_string() + R"(` )" +
              column["type"].get_string() +
              (default_value ? " DEFAULT " + default_value->get_string() : "") +
              R"( COMMENT \')" + column["id"].get_string() +
              R"(\', ')
,
  @sub_query
);
)";
    }
    sql_ += R"(
set @qry = if (@sub_query != '',
  concat('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
            R"(` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'No new column in ")" +
            table["name"].get_string() +
            R"(" is needed.\';'
);
)";
    sql_ += context_.exec;
    for (const auto &column : table["columns"].get_array()) {
      auto default_value = column.at("default");
      sql_ += R"(
set @old_column = null;
select `name` into @old_column
  from )" + Objects::planned_columns_from_json() +
              R"(
  where `comment` = ')" +
              column["id"].get_string() + R"(' and
      `table` = ')" +
              table["name"].get_string() + R"(';
set @next_ordinal = (
  select coalesce(max(`ordinal`), 0) + 1
  from )" + Objects::planned_columns_from_json() +
              R"(
  where `table` = ')" +
              table["name"].get_string() + R"('
);
set @_sql_columns = if(isnull(@old_column),
  json_array_append(@_sql_columns, '$', json_object(
      'table', ')" +
              table["name"].get_string() +
              R"(',
      'name', ')" +
              context_.bad_prefix + column["name"].get_string() +
              R"(',
      'comment', ')" +
              column["id"].get_string() +
              R"(',
      'type', ')" +
              column["type"].get_string() +
              R"(',
      'default', )" +
              (default_value ? default_value->get_string() : "null") +
              R"(,
      'nullable', 'YES',
      'auto', false,
      'ordinal', @next_ordinal
  )),
  @_sql_columns
);
)";
    }

    // Mark Extra columns
    sql_ += R"(
set @sub_query = null;
select group_concat(concat('RENAME COLUMN `', `name`, '` to `)" +
            context_.bad_prefix + context_.drop_prefix +
            R"(', `name`, '`') SEPARATOR ', ')
  into @sub_query
  from )" + Objects::planned_columns_from_json() +
            R"(
  where `name` not like ')" +
            context_.bad_prefix + context_.drop_prefix +
            R"(%' and `table` = ')" + table["name"].get_string() + R"(' and
      instr(@all_columns, concat('{', `comment`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra column in ")" +
            table["name"].get_string() + R"(".\';'
,
  concat('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
            R"(` ', @sub_query, ';')
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_indexes = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_indexes_from_json() +
            R"(
      where `table` != ')" +
            table["name"].get_string() +
            R"(' or `foreign_key` = true
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
);
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
        sql_ += R"(
set @_sql_indexes = json_array_append(@_sql_indexes, '$', json_object(
  'table', ')" + table["name"].get_string() +
                R"(',
  'name', ')" + key["name"].get_string() +
                R"(',
  'key_def', ')" +
                key_def +
                R"(',
  'foreign_key', false
));
)";
      }
    }
    sql_ += R"(
set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select
          `table`,
          if(`name` not like ')" +
            context_.bad_prefix + context_.drop_prefix +
            R"(%' and `table` = ')" + table["name"].get_string() +
            R"(' and instr(@all_columns, concat('{', `comment`, '}')) = 0,
              concat(')" +
            context_.bad_prefix + context_.drop_prefix +
            R"(', `name`),
              `name`
          ) as `name`,
          `comment`,
          `type`,
          `default_value`,
          `nullable`,
          `auto`,
          `ordinal`
      from )" +
            Objects::planned_columns_from_json() +
            R"(
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);
)";

    // Apply column names
    sql_ += R"(
set @ren_columns_prefix = '';
set @ren_columns_final = '';
)";
    for (const auto &column : table["columns"].get_array()) {
      sql_ += R"(
set @old_column = null;
select `name` into @old_column
  from )" + Objects::planned_columns_from_json() +
              R"(
  where `comment` = ')" +
              column["id"].get_string() + R"(' and
      `table` = ')" +
              table["name"].get_string() + R"(';
set @ren_columns_prefix = if (@old_column != ')" +
              column["name"].get_string() + R"(' && instr(@old_column, ')" +
              context_.bad_prefix + R"(') != 1,
  concat(@ren_columns_prefix, 'RENAME COLUMN `', @old_column, '` to `)" +
              context_.bad_prefix + column["name"].get_string() + R"(`, ')
,
  @ren_columns_prefix
);
set @ren_columns_final = if (@old_column != ')" +
              column["name"].get_string() + R"(',
  concat(@ren_columns_final, 'RENAME COLUMN `)" +
              context_.bad_prefix + column["name"].get_string() + R"(` to `)" +
              column["name"].get_string() + R"(`, ')
,
  @ren_columns_final
);
)";
    }
    sql_ += R"(
set @qry = if (@ren_columns_final != '',
  if (@ren_columns_prefix != '',
      concat ('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
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
    sql_ += context_.exec;
    for (const auto &column : table["columns"].get_array()) {
      sql_ +=
          R"(
set @old_column = null;
select `name` into @old_column
  from )" +
          Objects::planned_columns_from_json() +
          R"(
  where `comment` = ')" +
          column["id"].get_string() + R"(' and
      `table` = ')" +
          table["name"].get_string() + R"(';
set @new_column = if(@old_column != ')" +
          column["name"].get_string() + R"(' and instr(@old_column, ')" +
          context_.bad_prefix + R"(') != 1, ')" + context_.bad_prefix +
          column["name"].get_string() + R"(', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', ')" +
          column["id"].get_string() + R"(', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = ')" +
          table["name"].get_string() +
          R"(', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_indexes_from_json() +
          R"(
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = ')" +
          table["name"].get_string() +
          R"(', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = ')" +
          table["name"].get_string() +
          R"(', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_foreign_keys_from_json() +
          R"(
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));
)";
    }
    sql_ += R"(
set @qry = if (@ren_columns_final != '', concat ('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() + R"(` ',
  substr(@ren_columns_final, 1, length(@ren_columns_final) - 2), ';')
,
  'SET @r = \'No column in ")" +
            table["name"].get_string() +
            R"(" needs rename.\';');
)";
    sql_ += context_.exec;
    for (const auto &column : table["columns"].get_array()) {
      sql_ +=
          R"(
set @old_column = null;
select `name` into @old_column
  from )" +
          Objects::planned_columns_from_json() +
          R"(
  where `comment` = ')" +
          column["id"].get_string() + R"(' and
      `table` = ')" +
          table["name"].get_string() + R"(';
set @new_column = if(@old_column != ')" +
          column["name"].get_string() + R"(', ')" +
          column["name"].get_string() + R"(', @old_column);
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', ')" +
          column["id"].get_string() + R"(', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null or @new_column = @old_column,
  @_sql_columns,
  json_set(@_sql_columns, concat(@column_object, '.name'), @new_column)
);
set @_sql_indexes = if(@new_column = @old_column, @_sql_indexes, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = ')" +
          table["name"].get_string() +
          R"(', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'foreign_key', `foreign_key`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_indexes_from_json() +
          R"(
      order by `table`, `name`
  ) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(@new_column = @old_column, @_sql_foreign_keys, (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', if(`table` = ')" +
          table["name"].get_string() +
          R"(', replace(`key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `key_def`),
      'referenced_table', `referenced_table`,
      'f_key_def', if(`referenced_table` = ')" +
          table["name"].get_string() +
          R"(', replace(`f_key_def`, concat('`', @old_column, '`'), concat('`', @new_column, '`')), `f_key_def`),
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_foreign_keys_from_json() +
          R"(
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
));
)";
    }
  }
}

void Tables::drop_wrong_foreign_keys() {
  // Drop wrong foreign keys
  for (const auto &table : tables_.get_array()) {
    sql_ += R"(
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
        fk_flatten_columns_[table["name"].get_string()]
                           [key["name"].get_string()] = {std::move(key_def),
                                                         std::move(f_key_def)};
        sql_ += R"(
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
  `name`,
  `table`,
  `key_def`,
  `referenced_table`,
  `f_key_def`,
  `update_rule`,
  `delete_rule`
into
  @old_constraint,
  @old_table,
  @old_key_def,
  @old_referenced_table,
  @old_f_key_def,
  @old_update_rule,
  @old_delete_rule
from )" + Objects::planned_foreign_keys_from_json() +
                R"(
where `name` = ')" +
                key["name"].get_string() + R"(';
set @old_ok = 
  @old_table = ')" +
                table["name"].get_string() + R"(' and
  @old_key_def = ')" +
                fk_flatten_columns_[table["name"].get_string()]
                                   [key["name"].get_string()]
                                       .first +
                R"(' and
  @old_referenced_table = ')" +
                key["table"].get_string() + R"(' and
  @old_f_key_def = ')" +
                fk_flatten_columns_[table["name"].get_string()]
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
                context_.db_name +
                R"(`.`', @old_table, '` DROP FOREIGN KEY `)" +
                key["name"].get_string() + R"(`;'));
	)";
        sql_ += context_.exec;
        sql_ += R"(
set @_sql_foreign_keys = if(@old_ok or isnull(@old_constraint),
  @_sql_foreign_keys,
  (
      select coalesce(json_arrayagg(json_object(
          'table', `table`,
          'name', `name`,
          'key_def', `key_def`,
          'referenced_table', `referenced_table`,
          'f_key_def', `f_key_def`,
          'update', `update_rule`,
          'delete', `delete_rule`
      )), json_array())
      from (
          select *
          from )" +
                Objects::planned_foreign_keys_from_json() +
                R"(
          where not (`table` = @old_table and `name` = @old_constraint)
          order by `table`, `name`
      ) as `_sql_ordered_foreign_keys`
  )
);
)";
      }
    }

    // Remove extra foreign keys
    sql_ += R"(
set @sub_query = null;
select group_concat(distinct
  concat('DROP FOREIGN KEY `', `name`, '`') SEPARATOR ', ')
into @sub_query
from )" + Objects::planned_foreign_keys_from_json() +
            R"(
where
  `table` = ')" +
            table["name"].get_string() + R"(' and
  instr(@all_foreign_keys, concat('{', `name`, '}')) = 0;
set @qry = if (isnull(@sub_query),
  'SET @r = \'No extra foreign keys in ")" +
            table["name"].get_string() +
            R"(".\';'
,
  concat('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
            R"(` ', @sub_query, ';')
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_foreign_keys = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'key_def', `key_def`,
      'referenced_table', `referenced_table`,
      'f_key_def', `f_key_def`,
      'update', `update_rule`,
      'delete', `delete_rule`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_foreign_keys_from_json() +
            R"(
      where not (`table` = ')" +
            table["name"].get_string() +
            R"(' and instr(@all_foreign_keys, concat('{', `name`, '}')) = 0)
      order by `table`, `name`
  ) as `_sql_ordered_foreign_keys`
);
)";
  }
}

void Tables::apply_column_properties() {
  for (const auto &table : tables_.get_array()) {
    // Apply column properties
    sql_ += R"(
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
      sql_ +=
          R"(
set @old_type = null;
set @old_default = null;
set @old_null = null;
set @old_auto = null;
set @old_position = null;
select `type`, `default_value`, `nullable`, `auto`, `ordinal`
  into @old_type, @old_default, @old_null, @old_auto, @old_position
  from )" +
          Objects::planned_columns_from_json() +
          R"(
  where `name` = ')" +
          column["name"].get_string() + R"(' and
      `table` = ')" +
          table["name"].get_string() + R"(';
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
    sql_ += R"(
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
        sql_ += R"(
set @all_keys = concat(@all_keys, '{)" +
                key["name"].get_string() + R"(}');
set @old_index = null;
set @old_key_def = null;
select
  `name`,
  `key_def`
into
  @old_index,
  @old_key_def
from )" + Objects::planned_indexes_from_json() +
                R"(
where
  `table` = ')" +
                table["name"].get_string() + R"(' and
  `name` = ')" + key["name"].get_string() +
                R"(';
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
    sql_ += R"(
set @drop_query = null;
select group_concat(distinct
  concat('DROP INDEX `', `name`, '`') SEPARATOR ', ')
into @drop_query
from )" + Objects::planned_indexes_from_json() +
            R"(
where
  `foreign_key` = false and
  `table` = ')" +
            table["name"].get_string() + R"(' and
  instr(@all_keys, concat('{', `name`, '}')) = 0;
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);
)";
    // Remove extra columns
    sql_ += R"(
set @drop_query = null;
select group_concat(concat('DROP COLUMN `', `name`, '`')
  SEPARATOR ', ') into @drop_query
  from )" + Objects::planned_columns_from_json() +
            R"(
  where
      `table` = ')" +
            table["name"].get_string() + R"(' and
      `name` like ')" +
            context_.bad_prefix + context_.drop_prefix + R"(%';
set @sub_query = if (isnull(@drop_query), @sub_query,
  concat(@sub_query, @drop_query, ', ')
);
)";
    sql_ += R"(
set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
            R"(` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table ")" +
            table["name"].get_string() + R"(" is ok.\';'
);
)";
    sql_ += context_.exec;
    sql_ += R"(
set @_sql_columns = (
  select coalesce(json_arrayagg(json_object(
      'table', `table`,
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'default', `default_value`,
      'nullable', `nullable`,
      'auto', `auto`,
      'ordinal', `ordinal`
  )), json_array())
  from (
      select *
      from )" +
            Objects::planned_columns_from_json() +
            R"(
      where not (`table` = ')" +
            table["name"].get_string() + R"(' and `name` like ')" +
            context_.bad_prefix + context_.drop_prefix +
            R"(%')
      order by `table`, `ordinal`, `name`
  ) as `_sql_ordered_columns`
);
)";
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
      }
      sql_ += R"(
set @column_path = json_unquote(json_search(
  @_sql_columns, 'one', ')" +
              column["id"].get_string() + R"(', null, '$[*].comment'));
set @column_object = if(@column_path is null, null, replace(@column_path, '.comment', ''));
set @_sql_columns = if(@column_object is null,
  @_sql_columns,
  json_set(
      @_sql_columns,
      concat(@column_object, '.type'), ')" +
              column["type"].get_string() + R"(',
      concat(@column_object, '.default'), )" +
              (default_value ? default_value->get_string() : "null") + R"(,
      concat(@column_object, '.nullable'), ')" +
              (is_null ? "YES" : "NO") + R"(',
      concat(@column_object, '.auto'), )" +
              (is_auto ? "true" : "false") + R"(,
      concat(@column_object, '.ordinal'), )" +
              ordinal_position + R"(
  )
);
)";
    }
  }
}

void Tables::remove_extra_defaults() {
  for (const auto &table : tables_.get_array()) {
    // remove extra defaults
    sql_ += R"(
set @sub_query = '';
)";
    for (const auto &column : table["columns"].get_array()) {
      if (!column.at("default")) {
        sql_ +=
            R"(
set @old_default = null;
select `default_value`
  into @old_default
  from )" + Objects::planned_columns_from_json() +
            R"(
  where `name` = ')" +
            column["name"].get_string() + R"(' and
      `table` = ')" +
            table["name"].get_string() + R"(';
set @sub_query = if (@old_default IS NOT NULL,
  concat(@sub_query, 'ALTER COLUMN `)" +
            column["name"].get_string() + R"(` DROP DEFAULT, ')
,
  @sub_query
);
)";
      }
    }

    sql_ += R"(
set @qry = if (@sub_query != '',
  concat ('ALTER TABLE `)" +
            context_.db_name + R"(`.`)" + table["name"].get_string() +
            R"(` ', substr(@sub_query, 1, length(@sub_query) - 2), ';')
,
  'SET @r = \'Table ")" +
            table["name"].get_string() + R"(" is ok.\';'
);
)";
    sql_ += context_.exec;
  }
}

void Tables::remove_extra_tables() {
  // Remove extra tables
  sql_ += R"(
set @sub_query = null;
select group_concat(concat('`)" +
          context_.db_name + R"(`.`', `name`, '`')
  SEPARATOR ', ') into @sub_query
from )" + Objects::planned_tables_from_json() +
          R"(
where
  `type` = 'BASE TABLE' and
  `name` like ')" +
          context_.bad_prefix + context_.drop_prefix + R"(%';
set @qry = if (isnull(@sub_query), 'SET @r = \'No extra table.\';',
  concat('DROP TABLE ', @sub_query, ';')
);
)";
  sql_ += context_.exec;
  sql_ += R"(
set @_sql_tables = (
  select coalesce(json_arrayagg(json_object(
      'name', `name`,
      'comment', `comment`,
      'type', `type`,
      'engine', `engine`
  )), json_array())
  from (
      select *
      from )" +
          Objects::planned_tables_from_json() +
          R"(
      where not (`type` = 'BASE TABLE' and `name` like ')" +
          context_.bad_prefix + context_.drop_prefix + R"(%')
      order by `type`, `name`
  ) as `_sql_ordered_tables`
);
)";
}

void Tables::create_foreign_keys() {
  // Create foreign keys
  for (const auto &table : tables_.get_array()) {
    if (auto foreign_keys = table.at("foreign-keys"); foreign_keys) {
      for (const auto &key : foreign_keys->get_array()) {
        sql_ += R"(
set @old_constraint = null;
set @old_table = null;
set @old_key_def = null;
set @old_referenced_table = null;
set @old_f_key_def = null;
select `name` into @old_constraint
from )" + Objects::planned_foreign_keys_from_json() +
                R"(
where
  `table` = ')" +
                table["name"].get_string() + R"(' and
  `name` = ')" + key["name"].get_string() +
                R"(';
set @create_query = if (isnull(@old_constraint),
  concat('ALTER TABLE `)" +
                context_.db_name + R"(`.`)" + table["name"].get_string() +
                R"(` ADD CONSTRAINT `)" + key["name"].get_string() +
                R"(` FOREIGN KEY ()" +
                fk_flatten_columns_[table["name"].get_string()]
                                   [key["name"].get_string()]
                                       .first +
                R"() REFERENCES `)" + context_.db_name + R"(`.`)" +
                key["table"].get_string() + R"(` ()" +
                fk_flatten_columns_[table["name"].get_string()]
                                   [key["name"].get_string()]
                                       .second +
                R"() ON UPDATE )" + key["update"].get_string() +
                R"( ON DELETE )" + key["delete"].get_string() + R"(;')
  , '');
set @qry = if (@create_query != '', @create_query,
  'SET @r = \'Foreign key ")" +
                key["name"].get_string() + R"(" is ok.\';');
)";
        sql_ += context_.exec;
        sql_ += R"(
set @_sql_foreign_keys = if(isnull(@old_constraint),
  json_array_append(@_sql_foreign_keys, '$', json_object(
      'table', ')" +
                table["name"].get_string() +
                R"(',
      'name', ')" +
                key["name"].get_string() +
                R"(',
      'key_def', ')" +
                fk_flatten_columns_[table["name"].get_string()]
                                   [key["name"].get_string()]
                                       .first +
                R"(',
      'referenced_table', ')" +
                key["table"].get_string() +
                R"(',
      'f_key_def', ')" +
                fk_flatten_columns_[table["name"].get_string()]
                                   [key["name"].get_string()]
                                       .second +
                R"(',
      'update', ')" +
                key["update"].get_string() +
                R"(',
      'delete', ')" +
                key["delete"].get_string() + R"('
  )),
  @_sql_foreign_keys
);
)";
      }
    }
  }
}

void Tables::create_views() {
  // Create views
  for (const auto &table : tables_.get_array()) {
    if (auto views = table.at("views"); views) {
      for (const auto &view : views->get_array()) {
        sql_ += R"(
set @qry = 'CREATE OR REPLACE VIEW `)" +
                context_.db_name + R"(`.`)" + view["name"].get_string() +
                R"(` AS SELECT
)";
        std::string columns;
        for (const auto &clm : view["columns"].get_array()) {
          if (!columns.empty()) {
            columns += ", ";
          }
          columns +=
              "`" + table["name"].get_string() + "`.`" + clm.get_string() + "`";
        }
        std::string from = R"( FROM `)" + context_.db_name + R"(`.`)" +
                           table["name"].get_string() + R"(` )";
        for (const auto &joint : view["joints"].get_array()) {
          from += joint["type"].get_string() + R"( join `)" + context_.db_name +
                  R"(`.`)" + joint["table"].get_string() + R"(` AS `)" +
                  joint["as"].get_string() + R"(` ON )";
          std::string ons;
          for (const auto &on : joint["ons"].get_array()) {
            if (!ons.empty()) {
              ons += "AND ";
            }
            ons += R"(`)" + context_.db_name + R"(`.`)" +
                   on["base"]["table"].get_string() + R"(`.`)" +
                   on["base"]["column"].get_string() + R"(` = `)" +
                   context_.db_name + R"(`.`)" + joint["as"].get_string() +
                   R"(`.`)" + on["foreign"].get_string() + R"(` )";
          }
          from += ons;
          for (const auto &clm : joint["columns"].get_array()) {
            if (!columns.empty()) {
              columns += ", ";
            }
            columns += R"(`)" + context_.db_name + R"(`.`)" +
                       joint["as"].get_string() + R"(`.`)" +
                       clm["name"].get_string() + R"(` AS `)" +
                       clm["as"].get_string() + "`";
          }
        }
        sql_ += columns + from + R"(;';)";
        sql_ += context_.exec;
        sql_ += R"(
set @old_view = null;
select `name` into @old_view
  from )" + Objects::planned_views_from_json() +
                R"(
  where `name` = ')" +
                view["name"].get_string() + R"(';
set @_sql_views = if(isnull(@old_view),
  json_array_append(@_sql_views, '$', json_object(
      'name', ')" +
                view["name"].get_string() + R"('
  )),
  @_sql_views
);
)";
      }
    }
  }
}
std::string Tables::snapshot_schema_state(const std::string &db_name) {
  std::string sql;
  sql += R"(
set @_sql_tables = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'name', `name`,
    'comment', `comment`,
    'type', `type`,
    'engine', `engine`
)), json_array())
from (
    select
        `TABLE_NAME` as `name`,
        `TABLE_COMMENT` as `comment`,
        `TABLE_TYPE` as `type`,
        `ENGINE` as `engine`
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = ')" +
         db_name + R"('
    order by `TABLE_TYPE`, `TABLE_NAME`
) as `_sql_ordered_tables`
));
set @_sql_columns = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'table', `table`,
    'name', `name`,
    'comment', `comment`,
    'type', `type`,
    'default', `default_value`,
    'nullable', `nullable`,
    'auto', `auto`,
    'ordinal', `ordinal`
)), json_array())
from (
    select
        `TABLE_NAME` as `table`,
        `COLUMN_NAME` as `name`,
        `COLUMN_COMMENT` as `comment`,
        `COLUMN_TYPE` as `type`,
        `COLUMN_DEFAULT` as `default_value`,
        `IS_NULLABLE` as `nullable`,
        `EXTRA` like '%auto_increment%' as `auto`,
        `ORDINAL_POSITION` as `ordinal`
    from `INFORMATION_SCHEMA`.`COLUMNS`
    where `TABLE_SCHEMA` = ')" +
         db_name + R"('
    order by `TABLE_NAME`, `ORDINAL_POSITION`, `COLUMN_NAME`
) as `_sql_ordered_columns`
));
set @_sql_indexes = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'table', `table`,
    'name', `name`,
    'key_def', `key_def`,
    'foreign_key', `foreign_key`
)), json_array())
from (
    select
        `s`.`TABLE_NAME` as `table`,
        `s`.`INDEX_NAME` as `name`,
        group_concat(concat('`', `s`.`COLUMN_NAME`, '`')
            order by `s`.`SEQ_IN_INDEX` separator ', ') as `key_def`,
        exists (
            select 1
            from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE` as `kcu`
            where
                `kcu`.`CONSTRAINT_SCHEMA` = `s`.`INDEX_SCHEMA` and
                `kcu`.`TABLE_NAME` = `s`.`TABLE_NAME` and
                `kcu`.`CONSTRAINT_NAME` = `s`.`INDEX_NAME` and
                `kcu`.`REFERENCED_TABLE_NAME` is not null
        ) as `foreign_key`
    from `INFORMATION_SCHEMA`.`STATISTICS` as `s`
    where `s`.`INDEX_SCHEMA` = ')" +
         db_name + R"('
    group by `s`.`TABLE_NAME`, `s`.`INDEX_NAME`
    order by `s`.`TABLE_NAME`, `s`.`INDEX_NAME`
) as `_sql_ordered_indexes`
));
set @_sql_foreign_keys = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'table', `table`,
    'name', `name`,
    'key_def', `key_def`,
    'referenced_table', `referenced_table`,
    'f_key_def', `f_key_def`,
    'update', `update_rule`,
    'delete', `delete_rule`
)), json_array())
from (
    select
        `fk`.`TABLE_NAME` as `table`,
        `fk`.`CONSTRAINT_NAME` as `name`,
        `fk`.`key_def`,
        `fk`.`REFERENCED_TABLE_NAME` as `referenced_table`,
        `fk`.`f_key_def`,
        `rk`.`UPDATE_RULE` as `update_rule`,
        `rk`.`DELETE_RULE` as `delete_rule`
    from `INFORMATION_SCHEMA`.`REFERENTIAL_CONSTRAINTS` as `rk`
    join (
        select
            `CONSTRAINT_NAME`,
            `CONSTRAINT_SCHEMA`,
            `TABLE_NAME`,
            group_concat(concat('`', `COLUMN_NAME`, '`')
                order by `ORDINAL_POSITION` separator ', ') as `key_def`,
            `REFERENCED_TABLE_NAME`,
            group_concat(concat('`', `REFERENCED_COLUMN_NAME`, '`')
                order by `POSITION_IN_UNIQUE_CONSTRAINT` separator ', ') as `f_key_def`
        from `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`
        where
            `REFERENCED_TABLE_NAME` is not null and
            `CONSTRAINT_SCHEMA` = ')" +
         db_name + R"('
        group by `CONSTRAINT_NAME`, `CONSTRAINT_SCHEMA`, `TABLE_NAME`,
            `REFERENCED_TABLE_NAME`
    ) as `fk`
    using (
        `CONSTRAINT_SCHEMA`,
        `CONSTRAINT_NAME`,
        `TABLE_NAME`,
        `REFERENCED_TABLE_NAME`)
    order by `fk`.`TABLE_NAME`, `fk`.`CONSTRAINT_NAME`
) as `_sql_ordered_foreign_keys`
));
set @_sql_views = if(isnull(@old_db), json_array(), (
select coalesce(json_arrayagg(json_object(
    'name', `name`
)), json_array())
from (
    select `TABLE_NAME` as `name`
    from `INFORMATION_SCHEMA`.`TABLES`
    where `TABLE_SCHEMA` = ')" +
         db_name + R"(' and `TABLE_TYPE` = 'VIEW'
    order by `TABLE_NAME`
) as `_sql_ordered_views`
));
)";
  return sql;
}
