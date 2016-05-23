# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reboot_and_wait_up;
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

sub reboot_and_wait_up() {
	my $self=shift;
	my $reboot_timeout=shift;

	select_console('root-console');
	type_string("/sbin/reboot\n");
	reset_consoles;
	#wait_boot textmode => 1;
	sleep 2;
	#add switch xen kernel
	assert_screen "grub2", 120;
	if (!get_var("reboot_for_upgrade_step")) {
	    if (get_var("XEN")) {
	        send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 1);
	        send_key 'ret';
	    }
	}
	assert_screen(["generic-destop", "generic-destop-virt"], $reboot_timeout);
	select_console('root-console');

}

1;

