#include <stdlib.h>
 
/* Generate an MTE fault for a UAF (Use-After-Free):
 * - Use qemu with '-machine virt,mte=on -cpu max' _without_ kvm
 * - export GLIBC_TUNABLES="glibc.mem.tagging=X"
 *   where X has the following meanings:
 *     0        Disabled (default)
 *     1        asynchronous mode - useful to at least test and understand
 *     3        synchronous mode - what we probably want for openSUSE
 *   Details on: https://sourceware.org/pipermail/libc-alpha/attachments/20201218/cf93aeb4/attachment.bin
 */
 
int main(){
        int* a;
        a = malloc(sizeof(int));
        *a = 42;
        free(a);
        *a = 24; /* Should fail here */
        return 0;
}
