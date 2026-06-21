#ifndef SQLR_TEST_UTIL_H
#define SQLR_TEST_UTIL_H

#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include <json.hpp>

jsonio::json read_json(const std::string &text) {
  jsonio::json json;
  std::istringstream{text} >> json;
  return json;
}

std::string read_file(const std::string &name) {
  std::ifstream stream{std::string{SQLR_TEST_DIR} + "/" + name};
  return {std::istreambuf_iterator<char>{stream},
          std::istreambuf_iterator<char>{}};
}

std::string squish(const std::string &text) {
  std::string result;
  bool in_space = false;
  for (const auto c : text) {
    if (std::isspace(static_cast<unsigned char>(c))) {
      in_space = true;
      continue;
    }
    if (in_space && !result.empty()) {
      result += ' ';
    }
    result += c;
    in_space = false;
  }
  return result;
}

bool expect_sql(const std::string &actual, const std::string &expected,
                const char *test) {
  const auto normalized_actual = squish(actual);
  const auto normalized_expected = squish(expected);
  if (normalized_actual != normalized_expected) {
    std::cerr << test << std::endl;
    std::cerr << "Expected:\n" << normalized_expected << std::endl;
    std::cerr << "Actual:\n" << normalized_actual << std::endl;
    return false;
  }
  return true;
}

#endif // SQLR_TEST_UTIL_H
