/*
 * extremely trivial usage of bzlib ... just to see if it usable at all
 * by Frank Seidel <fseidel@suse.de> / 2005-10-06
 */

#include <stdio.h>
#include <assert.h>
#include <unistd.h>

#include <bzlib.h>


int main(int argc,char *argv[])
{
	BZFILE *writefile=NULL, *readfile=NULL;
	int filedescriptor[2];
		
	assert(! pipe(filedescriptor));	

	printf("Trying read-open API..\n");
	assert(readfile = BZ2_bzdopen(filedescriptor[0], "r"));
	printf("Trying write-open API..\n");
	assert(writefile = BZ2_bzdopen(filedescriptor[1], "w"));
	
	printf("Trying close API..\n");
	BZ2_bzclose(writefile);
	BZ2_bzclose(readfile);

	return(0);
}

