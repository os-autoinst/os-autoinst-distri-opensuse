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
  char *cstr = (char*)'five';
  char * newstr = str_dup(cstr, 32); // len is intentionally longer to cause an access violation
  return 0;
}
