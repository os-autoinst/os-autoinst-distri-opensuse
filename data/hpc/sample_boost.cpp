/**
https://www.boost.org/doc/libs/1_78_0/doc/html/mpi/tutorial.html
**/
#include <boost/mpi/environment.hpp>
#include <boost/mpi/communicator.hpp>
#include <iostream>
namespace mpi = boost::mpi;

int main(int argc, char* argv[])
{
  mpi::environment env(argc, argv);
  mpi::communicator world;
  std::cout << "I am process " << world.rank() << " of " << world.size()
	    << "." << std::endl;
  return 0;
}
