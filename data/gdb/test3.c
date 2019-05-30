#include <stdio.h>
#include <stdlib.h>

int main()
{
  volatile int n=0;
  for (;;)
    {
      n=1000*rand();
    }
  return 0;
}
