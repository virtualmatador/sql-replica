#include <fstream>
#include <iostream>
#include <sstream>

#include <cli.h>
#include <json.h>
#include <sqlr.h>

int main(int argc, const char* argv[])
{
    std::string name;
    jsonio::json_arr db, clients;
    jsonio::json report = false;
    bool convert = false;
    std::vector<std::string> errors;
    try
    {
        Cli::parse(argc, argv,
        {
            {
                { "--version", "-v" },
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    std::cout << "SQL Replica, Version: " << VERSION <<
                        std::endl;
                }, 0, 0})
            },
            {
                { "--report", "-r" },
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    std::istringstream(args[0]) >> report;
                    if (report.type() != jsonio::JsonType::J_BOOL)
                    {
                        errors.emplace_back(
                            "Report flag is not valid: " + args[0]);
                    }
                    convert = true;
                }, 1, 1})
            },
            {
                { "--name", "-n" },
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    name = args[0];
                    convert = true;
                }, 1, 1})
            },
            {
                { "--client", "-c" },
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    jsonio::json_obj client;
                    client["user"] = args[0];
                    jsonio::json_arr permissions;
                    std::ifstream(args[1]) >> permissions;
                    if (!permissions.completed())
                    {
                        errors.emplace_back(
                            "Permissions file is not valid: " + args[1]);
                    }
                    client["permissions"] = std::move(permissions);
                    clients.emplace_back(std::move(client));
                    convert = true;
                }, 2, 2})
            },
            {
                { "" },
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    std::ifstream(args[0]) >> db;
                    if (!db.completed())
                    {
                        errors.emplace_back(
                            "Database file is not valid: " + args[0]);
                    }
                    convert = true;
                }, 1, 1})
            }
        });
        if (errors.empty())
        {
            if (convert)
            {
                std::cout << replicate_sql(
                    report.get_bool(), name, db, clients) << std::endl;
            }
        }
        else
        {
            for (const auto& error : errors)
            {
                std::cerr << error << std::endl;
            }
        }
    }
    catch(const std::exception& e)
    {
        std::cerr << e.what() << std::endl;
    }
    return 0;
}
