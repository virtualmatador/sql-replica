#ifndef CONTEXT_H
#define CONTEXT_H

#include <string>

struct Context {
  std::string db_name;
  std::string bad_prefix;
  std::string drop_prefix;
  std::string exec;
};

#endif // CONTEXT_H
