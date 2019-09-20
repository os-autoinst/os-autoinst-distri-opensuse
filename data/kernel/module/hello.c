/* Example from http://www.tldp.org/LDP/lkmpg/2.6/html/x121.html */

#include <linux/module.h>
#include <linux/kernel.h>
int init_module(void)
{
 printk(KERN_INFO "Hello world.\n");
 return 0;
}
void cleanup_module(void)
{
 printk(KERN_INFO "Goodbye world.\n");
}
