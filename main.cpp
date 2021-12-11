#include <fstream>
#include <iostream>
#include <sstream>

#include <cli.h>
#include <json.h>
#include <sqlr.h>

void version()
{
    std::cout << "SQL Replica, Version: " << VERSION << std::endl;
}

jsonio::json read_json(const std::string& file_name)
{
    std::ifstream the_file{ file_name };
    if (!the_file)
    {
        throw std::runtime_error("Cannot Read File");
    }
    jsonio::json the_json;
    the_file >> the_json;
    if (!the_json.completed())
    {
        throw std::runtime_error("Bad Json");
    }
    return the_json;
}

void convert(const std::string& db_name,
    const std::string& sql_file_name, const std::string& clients_file_name)
{
    jsonio::json sql_json = read_json(sql_file_name);
    jsonio::json clients_json;
    if (!clients_file_name.empty())
    {
        clients_json = read_json(clients_file_name);
    }
    else
    {
        std::istringstream("[]") >> clients_json;
    }
    std::cout << replicate_sql(db_name, sql_json, clients_json) << std::endl;
}

int main(int argc, const char* argv[])
{
    try
    {
        Cli::parse(argc, argv,
        {
            {
                "--version",
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    version();
                }, 0, 0})
            },
            {
                "-v",
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    version();
                }, 0, 0})
            },
            {
                "",
                Cli::Handler({ [&](const std::vector<std::string>& args)
                {
                    convert(args[0], args[1], args.size() > 2 ? args[2] : "");
                }, 2, 3})
            }
        });
    }
    catch(const std::exception& e)
    {
        std::cerr << e.what() << std::endl;
    }
    return 0;
}
