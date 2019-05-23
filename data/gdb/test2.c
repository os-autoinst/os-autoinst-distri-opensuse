#include <string.h>
#include <malloc.h>

char *str_dup(char *src, int len){
  char* dst = malloc(len*sizeof(char));
  for (int i=0;i<len;i++)
    {
      *dst=*src;
    }
  return dst;
}

int main()
{
  char *cstr = 'five';
  char * newstr = str_dup(cstr, 5);
  return 0;
}
