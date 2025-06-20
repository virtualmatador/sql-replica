#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>

#include <json.hpp>

#include <cli.h>
#include <sqlr.h>

int main(int argc, const char *argv[]) {
  std::string name;
  jsonio::json db, clients = jsonio::json_arr{};
  bool report = false, dry_run = false;
  std::string output_file;
  bool convert = false;
  std::vector<std::string> errors;
  Cli::parse(
      argc, argv,
      {{{"--version", "-v"},
        Cli::Handler({[&](auto &&args) {
                        std::cout << "SQL Replica, Version: " << VERSION
                                  << std::endl;
                      },
                      0, 0})},
       {{"--report", "-r"},
        Cli::Handler({[&](auto &&args) {
                        report = true;
                        convert = true;
                      },
                      0, 0})},
       {{"--dry-run", "-d"},
        Cli::Handler({[&](auto &&args) {
                        dry_run = true;
                        convert = true;
                      },
                      0, 0})},
       {{"--name", "-n"},
        Cli::Handler({[&](auto &&args) {
                        name = args[0];
                        convert = true;
                      },
                      1, 1})},
       {{"--client", "-c"},
        Cli::Handler({[&](auto &&args) {
                        jsonio::json_obj client;
                        if (args.size() == 1 || args[0].empty()) {
                          client["user"] =
                              std::filesystem::path{args.back()}.stem();
                        } else {
                          client["user"] = args[0];
                        }
                        std::ifstream(args.back()) >> client["permissions"];
                        if (client["permissions"].completed() &&
                            client["permissions"].type() ==
                                jsonio::JsonType::J_ARRAY) {
                          clients.get_array().emplace_back(std::move(client));
                          convert = true;
                        } else {
                          errors.emplace_back(
                              "Permissions file is not valid: " + args.back());
                        }
                      },
                      1, 2})},
       {{"--out", "-o"},
        Cli::Handler({[&](auto &&args) {
                        output_file = args[0];
                        convert = true;
                      },
                      1, 1})},
       {{""},
        Cli::Handler({[&](auto &&args) {
                        std::ifstream(args[0]) >> db;
                        if (db.completed()) {
                          if (name.empty()) {
                            name = std::filesystem::path{args[0]}.stem();
                          }
                          convert = true;
                        } else {
                          errors.emplace_back("Database file is not valid: " +
                                              args[0]);
                        }
                      },
                      1, 1})}});
  try {
    if (errors.empty()) {
      if (convert) {
        if (db.type() != jsonio::JsonType::J_ARRAY) {
          throw std::runtime_error("No tables file provided.");
        }
        std::ostream *os;
        std::ofstream ofs;
        if (output_file.empty()) {
          os = &std::cout;
        } else {
          ofs.open(output_file);
          os = &ofs;
        }
        (*os) << replicate_sql(name, db, clients, report, dry_run) << std::endl;
      }
    } else {
      for (const auto &error : errors) {
        std::cerr << error << std::endl;
      }
      return EXIT_FAILURE;
    }
  } catch (const std::exception &e) {
    std::cerr << "Error: " << e.what() << std::endl;
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}
