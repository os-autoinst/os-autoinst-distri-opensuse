#include <stdio.h>
#include <linux/bpf.h>
#include <sys/syscall.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

/*
 * on success, this function returns a file descriptor.
 * on error, -1 is returned and errno is set to
 * EINVAL, EPERM, or ENOMEM.
 */
int sys_bpf(enum bpf_cmd cmd, union bpf_attr *attr, unsigned int size)
{
        return syscall(__NR_bpf, cmd, attr, size);
}

int main(int argc, char **argv)
{
        // redirect stderr to stdout
        dup2(1, 2);
        // refer: https://github.com/torvalds/linux/tree/master/samples/bpf
        union bpf_attr attr;
        memset(&attr, 0, sizeof(attr));

        attr.map_type    = BPF_MAP_TYPE_ARRAY;
        attr.key_size    = sizeof(int);
        attr.value_size  = sizeof(int);
        attr.max_entries = 1;

        int fd = sys_bpf(BPF_MAP_CREATE, &attr, sizeof(attr));
        perror("BPF");

        // release file descriptor
        if (fd > 0) {
                close(fd);
        }

        return 0;
}