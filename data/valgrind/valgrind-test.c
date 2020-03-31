/* Valgrind test program
 * 
 * Copyright © 2020 SUSE LLC
 * 
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.  This file is offered as-is,
 * without any warranty.
 * 
 * Memory leak, uninitialzed values, out-of-bounds read test program to testing
 * valgrind
 * 
 * Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>
 * 
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <sys/wait.h>

// memory pointers for still_reachable
static void* mem_pointers[64];
static int mem_pointer_i = 0;

void say(const char* string) {
	printf(string);
}
void say_hello() {
	say("Hello World!\n");
}

void* leak_some_mem(size_t size) {
	if(size == 0) {
		errno = EINVAL;
		return NULL;
	}
	void* mem = malloc(size);
	return mem;
}

/* create simple xor hash over the defined memory region. return value is 
 * always positive */
int xor_hash(const char* mem, const size_t n) {
	int hash = 0;
	for(size_t i=0;i<n;i++)
		hash ^= mem[i];
	return hash>=0?hash:-hash;
}

/* Test for uninitialized read. Allocates size bytes and
 * creates a simple hash over the allocated region.
 * returns the hash of the region on success (zero or positive) or -1 on error */
int uninitialized(size_t size) {
	void *mem = malloc(size);
	if(mem == NULL)
		return -1;
	
	int ret = xor_hash(mem, size);
	free(mem);
	return ret;
}

/* out of bytes read. Allocates alloc bytes and creates a simple XOR hash over 
 * the allocated region+n bytes
 */ 
int oob(size_t size, size_t n) {
	void *mem = malloc(size);
	if(mem == NULL)
		return -1;
	
	int ret = xor_hash(mem, size+n);
	free(mem);
	return ret;
}

/* Performs an out-of bounds read on a stack array. The array is nulled and
 * exactly 64 bytes long, so every n>64 will trigger the read */
int oob_stack(size_t n) {
	char array[64];
	bzero(array, sizeof(char)*64);
	return xor_hash(array, n);
}

void printHelp(const char* progname) {
	printf("Valgrind test program\n  Usage: %s [OPTIONS]\n\n", progname);
	printf("OPTIONS\n\n");
	printf("  --sayhello                Print hello (two function calls)\n");
	printf("  --fork                    Fork to child (Use this as first argument!)\n");
	printf("  --leak BYTES              Leak defined amount of memory\n");
	printf("  --still-reachable BYTES   Leak defined amount of memory as still-reachable\n");
	printf("  --uninitialized BYTES     Test for usage of uninitialized memory\n");
	printf("  --oob ALLOC BYTES         Allocate ALLOC bytes and read BYTES bytes larger than ALLOC\n");
	printf("  --oob-stack BYTES         Perform out-of-bounds read from stack\n");
	printf("                            Allocates 64 bytes of nulled space on the stack, so every BYTES>64 will trigger an oob\n");
	printf("\n");
}

int main(int argc, char** argv) {
	int ret = EXIT_SUCCESS;
	for (int i=1;i<argc;i++) {
		const char *arg = argv[i];
		if(strcmp("--help", arg) == 0 || strcmp("-h", arg) == 0) {
			printHelp(argv[0]);
			exit(EXIT_SUCCESS);
		} else if(strcmp("--sayhello", arg) == 0) {
			say_hello();
		} else if(strcmp("--fork", arg) == 0) {
			// Fork to child, wait for child to exit and return exit code of child
			pid_t pid = fork();
			if (pid < 0) {
				fprintf(stderr, "Fork failed: %s\n", strerror(errno));
				exit(EXIT_FAILURE);
			} else if (pid > 0) {
				pid = waitpid(pid, &ret, 0);
				exit(WEXITSTATUS(ret));
			} // else - child, resume from here
		} else if(strcmp("--leak", arg) == 0) {
			if(leak_some_mem(atol(argv[++i])) == NULL) {
				fprintf(stderr, "Allocating leaking memory failed: %s\n", strerror(errno));
				ret = EXIT_FAILURE;
			}
		} else if(strcmp("--still-reachable", arg) == 0) {
			mem_pointers[mem_pointer_i++] = leak_some_mem(atol(argv[++i]));
			if(mem_pointers[mem_pointer_i-1] == NULL) {
				fprintf(stderr, "Allocating still-reachable memory failed: %s\n", strerror(errno));
				ret = EXIT_FAILURE;
			}
		} else if(strcmp("--uninitialized", arg) == 0) {
			if(uninitialized(atol(argv[++i])) < 0) {
				fprintf(stderr, "Error reading uninitialzed memory: %s\n", strerror(errno));
			}
		} else if(strcmp("--oob", arg) == 0) {
			if(oob(atol(argv[i+1]), atol(argv[i+2])) < 0) {
				fprintf(stderr, "Error reading oob memory: %s\n", strerror(errno));
			}
			i+=2;
		} else if(strcmp("--oob-stack", arg) == 0) {
			if(oob_stack(atol(argv[++i])) < 0) {
				fprintf(stderr, "Error reading oob-stack memory: %s\n", strerror(errno));
			}
		} else {
			fprintf(stderr, "Illegal argument: %s\n", arg);
			ret = EXIT_FAILURE;
		}
	}
	return ret;
}
