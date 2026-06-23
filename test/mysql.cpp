#include <chrono>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>
#include <vector>

#include <schema.h>

#include "test_util.h"

namespace {

struct CommandResult {
  int exit_code = 1;
  std::string output;
};

std::string shell_quote(const std::string &text) {
  std::string result = "'";
  for (const auto c : text) {
    if (c == '\'') {
      result += "'\\''";
    } else {
      result += c;
    }
  }
  result += "'";
  return result;
}

std::string shell_join(const std::vector<std::string> &args) {
  std::string command;
  for (const auto &arg : args) {
    if (!command.empty()) {
      command += " ";
    }
    command += shell_quote(arg);
  }
  return command;
}

bool exists_on_path(const std::string &name) {
  const auto path = std::getenv("PATH");
  if (path == nullptr) {
    return false;
  }

  std::stringstream stream{path};
  std::string dir;
  while (std::getline(stream, dir, ':')) {
    auto candidate = std::filesystem::path{dir} / name;
    if (access(candidate.c_str(), X_OK) == 0) {
      return true;
    }
  }
  return false;
}

std::string make_container_name() {
  auto pattern = std::filesystem::temp_directory_path() / "sqlr-mysql-XXXXXX";
  auto text = pattern.string();
  std::vector<char> buffer{text.begin(), text.end()};
  buffer.push_back('\0');
  if (mkdtemp(buffer.data()) == nullptr) {
    throw std::runtime_error(std::string{"mkdtemp failed: "} +
                             std::strerror(errno));
  }
  const auto path = std::filesystem::path{buffer.data()};
  std::error_code ec;
  std::filesystem::remove_all(path, ec);
  return path.filename().string();
}

std::string read_text(const std::filesystem::path &path) {
  std::ifstream stream{path};
  if (!stream) {
    throw std::runtime_error("could not open " + path.string());
  }
  return {std::istreambuf_iterator<char>{stream},
          std::istreambuf_iterator<char>{}};
}

std::filesystem::path make_temp_file(const char *prefix) {
  auto pattern =
      std::filesystem::temp_directory_path() / (std::string{prefix} + "XXXXXX");
  auto text = pattern.string();
  std::vector<char> buffer{text.begin(), text.end()};
  buffer.push_back('\0');
  const int fd = mkstemp(buffer.data());
  if (fd < 0) {
    throw std::runtime_error(std::string{"mkstemp failed: "} +
                             std::strerror(errno));
  }
  close(fd);
  return buffer.data();
}

CommandResult run_command(const std::vector<std::string> &args,
                          const std::string &input,
                          std::chrono::seconds timeout =
                              std::chrono::seconds{30}) {
  const auto input_path = make_temp_file("sqlr-mysql-in.");
  {
    std::ofstream stream{input_path};
    stream << input;
  }

  auto command = "timeout " + std::to_string(timeout.count()) + " " +
                 shell_join(args) + " < " + shell_quote(input_path.string());
  char buffer[1024];
  std::string output;
  FILE *fp = popen(("{\n" + command + "\n} 2>&1").c_str(), "r");
  if (fp == nullptr) {
    throw std::runtime_error("command closed");
  }
  while (fgets(buffer, sizeof(buffer) - 1, fp) != nullptr) {
    output += buffer;
  }
  const int status = pclose(fp);
  std::error_code ec;
  std::filesystem::remove(input_path, ec);

  if (WIFEXITED(status)) {
    return {WEXITSTATUS(status), output};
  }
  if (WIFSIGNALED(status)) {
    return {128 + WTERMSIG(status), output};
  }
  return {1, output};
}

class MysqlContainer {
public:
  MysqlContainer() : container_(make_container_name()) {
    start();
    wait_until_ready();
  }

  MysqlContainer(const MysqlContainer &) = delete;
  MysqlContainer &operator=(const MysqlContainer &) = delete;

  ~MysqlContainer() {
    stop();
  }

  std::string exec(const std::string &sql) const {
    auto args = mysql_args();
    args.push_back("--batch");
    args.push_back("--raw");
    args.push_back("--skip-column-names");
    const auto result = run_command(args, sql);
    if (result.exit_code != 0) {
      throw std::runtime_error("mysql failed:\n" + result.output +
                               "\ncontainer log:\n" + logs());
    }
    return result.output;
  }

  std::string check(const std::string &sql) const {
    auto args = mysql_args();
    args.push_back("--batch");
    args.push_back("--skip-column-names");
    const auto result = run_command(args, sql);
    if (result.exit_code != 0) {
      throw std::runtime_error("mysql checker failed:\n" + result.output +
                               "\ncontainer log:\n" + logs());
    }
    return squish(result.output);
  }

  std::string report(const std::string &sql) const {
    auto args = mysql_args();
    args.push_back("--batch");
    args.push_back("--raw");
    args.push_back("--skip-column-names");
    const auto result = run_command(args, sql);
    if (result.exit_code != 0) {
      throw std::runtime_error("mysql report failed:\n" + result.output +
                               "\ncontainer log:\n" + logs());
    }
    return result.output;
  }

private:
  std::vector<std::string> mysql_args() const {
    return {"docker", "exec", "-i", container_, "mysql", "--user=root",
            "--connect-timeout=1"};
  }

  std::string logs() const {
    return run_command({"docker", "logs", container_}, "",
                       std::chrono::seconds{10})
        .output;
  }

  void start() const {
    const auto image = std::getenv("SQLR_MYSQL_IMAGE") != nullptr
                           ? std::getenv("SQLR_MYSQL_IMAGE")
                           : std::string{"mysql:8"};
    const auto result =
        run_command({"docker",
                     "run",
                     "--detach",
                     "--rm",
                     "--name",
                     container_,
                     "--env",
                     "MYSQL_ALLOW_EMPTY_PASSWORD=yes",
                     "--tmpfs",
                     "/var/lib/mysql",
                     image},
                    "", std::chrono::seconds{60});
    if (result.exit_code != 0) {
      throw std::runtime_error("docker run failed:\n" + result.output);
    }
  }

  void wait_until_ready() const {
    const auto deadline = std::chrono::steady_clock::now() +
                          std::chrono::seconds{90};
    while (std::chrono::steady_clock::now() < deadline) {
      const auto running =
          run_command({"docker", "inspect", "-f", "{{.State.Running}}",
                       container_},
                      "", std::chrono::seconds{10});
      if (running.exit_code != 0 || squish(running.output) != "true") {
        throw std::runtime_error("mysql container exited before ready:\n" +
                                 logs());
      }

      const auto current_logs = logs();
      if (current_logs.find("MySQL init process done. Ready for start up.") ==
          std::string::npos) {
        std::this_thread::sleep_for(std::chrono::milliseconds{500});
        continue;
      }

      if (run_command({"docker", "exec", container_, "mysqladmin", "ping",
                       "--user=root", "--silent"},
                      "", std::chrono::seconds{10})
              .exit_code == 0) {
        return;
      }

      std::this_thread::sleep_for(std::chrono::milliseconds{500});
    }
    throw std::runtime_error("mysql container did not become ready:\n" +
                             logs());
  }

  void stop() {
    run_command({"docker", "rm", "--force", container_}, "",
                std::chrono::seconds{30});
  }

  std::string container_;
};

jsonio::json read_json_file(const std::filesystem::path &path) {
  jsonio::json json;
  std::ifstream stream{path};
  if (!stream) {
    throw std::runtime_error("could not open " + path.string());
  }
  stream >> json;
  return json;
}

std::string normalize_log(const std::string &text) {
  std::string result = text;
  std::stringstream stream{text};
  std::string line;
  while (std::getline(stream, line)) {
    if (line.rfind("DELIMITER d", 0) != 0 || line.size() != 24) {
      continue;
    }
    const auto delimiter = line.substr(10);
    if (!std::regex_match(delimiter, std::regex{"d[0-9a-f]{13}"})) {
      continue;
    }
    std::size_t pos = 0;
    while ((pos = result.find(delimiter, pos)) != std::string::npos) {
      result.replace(pos, delimiter.size(), "<delimiter>");
      pos += std::string{"<delimiter>"}.size();
    }
  }
  return result;
}

void write_text(const std::filesystem::path &path, const std::string &text) {
  std::ofstream stream{path};
  if (!stream) {
    throw std::runtime_error("could not write " + path.string());
  }
  stream << text;
}

bool compare_log(const std::filesystem::path &path, const std::string &actual) {
  const auto normalized = normalize_log(actual);
  if (std::getenv("SQLR_UPDATE_MYSQL_LOGS") != nullptr) {
    write_text(path, normalized);
    return true;
  }
  if (!std::filesystem::exists(path)) {
    std::cerr << "mysql: missing log " << path.string() << std::endl;
    return false;
  }
  const auto expected = read_text(path);
  if (expected == normalized) {
    return true;
  }
  std::cerr << "mysql: log mismatch for " << path.string() << std::endl;
  std::cerr << "Expected:\n" << expected << std::endl;
  std::cerr << "Actual:\n" << normalized << std::endl;
  return false;
}

std::vector<std::string> apply_schema(MysqlContainer &mysql,
                                      const jsonio::json &schema,
                                      bool report_mode) {
  std::vector<std::string> logs;
  if (!report_mode) {
    const auto generated = Schema(schema, true, false).replicate_sql();
    for (int i = 0; i < 2; ++i) {
      logs.push_back(mysql.exec(generated));
    }
    return logs;
  }

  const auto generated = Schema(schema, true, true).replicate_sql();
  for (int i = 0; i < 2; ++i) {
    auto report = mysql.report(generated);
    logs.push_back(report);
    mysql.exec(report);
  }
  return logs;
}

bool run_mysql_fixture(const std::filesystem::path &folder) {
  if (!exists_on_path("docker")) {
    std::cerr << "mysql: skipping, docker not found on PATH" << std::endl;
    return true;
  }

  if (!std::filesystem::is_directory(folder)) {
    std::cerr << "mysql: fixture folder not found: " << folder.string()
              << std::endl;
    return false;
  }

  MysqlContainer mysql;
  const bool report_mode = std::filesystem::exists(folder / "dry-run-report");
  bool found_step = false;
  for (int j = 1;; ++j) {
    const auto base = folder / std::to_string(j);
    const auto json_path = base.string() + ".json";
    const auto checker_path = base.string() + ".sql";
    if (!std::filesystem::exists(json_path) &&
        !std::filesystem::exists(checker_path)) {
      break;
    }
    if (!std::filesystem::exists(json_path) ||
        !std::filesystem::exists(checker_path)) {
      std::cerr << "mysql: missing json/sql pair for " << base.string()
                << std::endl;
      return false;
    }
    found_step = true;

    const auto logs = apply_schema(mysql, read_json_file(json_path), report_mode);
    if (report_mode) {
      if (logs.size() != 2 ||
          !compare_log(base.string() + ".log", logs[0]) ||
          !compare_log(base.string() + ".2.log", logs[1])) {
        return false;
      }
    } else {
      std::string combined_log;
      for (std::size_t i = 0; i < logs.size(); ++i) {
        combined_log += "-- pass " + std::to_string(i + 1) + "\n";
        combined_log += logs[i];
      }
      if (!compare_log(base.string() + ".log", combined_log)) {
        return false;
      }
    }

    const auto result = mysql.check(read_text(checker_path));
    if (result != "ok") {
      std::cerr << "mysql: checker failed for " << base.string()
                << ", expected ok, got " << result << std::endl;
      return false;
    }
  }

  if (!found_step) {
    std::cerr << "mysql: no steps in " << folder.string() << std::endl;
    return false;
  }
  return true;
}

bool run_mysql_fixtures() {
  const auto root = std::filesystem::path{SQLR_TEST_DIR} / "mysql";
  bool found_folder = false;

  for (int i = 1;; ++i) {
    const auto folder = root / std::to_string(i);
    if (!std::filesystem::is_directory(folder)) {
      break;
    }
    found_folder = true;
    if (!run_mysql_fixture(folder)) {
      return false;
    }
  }

  if (found_folder) {
    return true;
  }

  std::cerr << "mysql: no fixture folders found in " << root.string()
            << std::endl;
  return false;
}

} // namespace

int main(int argc, char **argv) {
  try {
    if (argc == 2) {
      return run_mysql_fixture(argv[1]) ? 0 : -1;
    }
    if (argc == 1) {
      return run_mysql_fixtures() ? 0 : -1;
    }
    std::cerr << "usage: sqlr-mysql [fixture-folder]" << std::endl;
    return -1;
  } catch (const std::exception &e) {
    std::cerr << "mysql: " << e.what() << std::endl;
    return -1;
  }
}
