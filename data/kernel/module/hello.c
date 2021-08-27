/*
 * Example from http://www.tldp.org/LDP/lkmpg/2.6/html/x121.html
 * Updated to the current standard
 */

#include <linux/module.h>
#include <linux/kernel.h>

static int __init hello_init_module(void)
{
	printk(KERN_INFO "Hello world.\n");

	return 0;
}

static void __exit hello_cleanup_module(void)
{
	printk(KERN_INFO "Goodbye world.\n");
}

module_init(hello_init_module)
module_exit(hello_cleanup_module)
MODULE_LICENSE("GPL");
