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
                    client.insert({ "user", args[0] });
                    jsonio::json_arr permissions;
                    std::ifstream(args[1]) >> permissions;
                    client.insert({ "permissions", std::move(permissions) });
                    clients.emplace_back(std::move(client));
                    convert = true;
                }, 2, 2})
            },
            {
                { "" },
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    std::ifstream(args[0]) >> db;
                    convert = true;
                }, 1, 1})
            }
        });
        if (convert)
        {
            std::cout << replicate_sql(
                report.get_bool(), name, db, clients) << std::endl;
        }
    }
    catch(const std::exception& e)
    {
        std::cerr << e.what() << std::endl;
    }
    return 0;
}
