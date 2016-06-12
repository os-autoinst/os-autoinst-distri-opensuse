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
#package login_console;

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

sub run() { 
	# Wait for bootload for the first time.
	assert_screen "grub2", 120;
	if (get_var("XEN")) {
		send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 1);
		send_key 'ret';
	}
	
	assert_screen(["generic-destop", "generic-destop-virt","displaymanager"], 300);
	select_console('root-console');
	
	sleep 3;
}

sub test_flags {
    return {important => 1};
}

1;

