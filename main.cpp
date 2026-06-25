#include <fstream>
#include <iostream>

#include <json.hpp>

#include <cli.h>
#include <schema.h>

int main(int argc, const char *argv[]) {
  jsonio::json schema;
  bool report = false, dry_run = false;
  bool convert = true;
  std::string input_file;
  std::string output_file;
  try {
    Cli::parse(
        argc, argv,
        {{{"--version", "-v"},
          Cli::Handler({[&](auto &&args) {
                          std::cout << "SQL Replica, Version: " << VERSION
                                    << std::endl;
                          convert = false;
                        },
                        0, 0})},
         {{"--report", "-r"},
          Cli::Handler({[&](auto &&args) { report = true; }, 0, 0})},
         {{"--dry-run", "-d"},
          Cli::Handler({[&](auto &&args) { dry_run = true; }, 0, 0})},
         {{"--input-file", "-i"},
          Cli::Handler({[&](auto &&args) { input_file = args[0]; }, 1, 1})},
         {{"--output-file", "-o"},
          Cli::Handler({[&](auto &&args) { output_file = args[0]; }, 1, 1})}});
    if (convert) {
      if (input_file.empty()) {
        std::cin >> schema;
      } else {
        std::ifstream input{input_file};
        if (!input.is_open()) {
          throw std::runtime_error("Could not open schema file: " + input_file);
        }
        input >> schema;
      }
      if (!schema.completed()) {
        throw std::runtime_error("Schema input is not valid.");
      }
      const auto sql = Schema(schema, report, dry_run).replicate_sql();
      std::ostream *os;
      std::ofstream ofs;
      if (output_file.empty()) {
        os = &std::cout;
      } else {
        ofs.open(output_file);
        if (!ofs.is_open()) {
          throw std::runtime_error("Could not open output file: " +
                                   output_file);
        }
        os = &ofs;
      }
      (*os) << sql << std::endl;
    }
  } catch (const std::exception &e) {
    std::cerr << "Error: " << e.what() << std::endl;
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}
