// C++ test
#include <pcrecpp.h>
#include <assert.h>
#include <stdio.h>

int main() {
   pcrecpp::RE re("h.*o");
   assert(re.FullMatch("hello"));
   assert(!re.FullMatch("Hello"));
   assert(!re.FullMatch("hello world"));
   puts("pcrecpp worked");
   return 0;
}

