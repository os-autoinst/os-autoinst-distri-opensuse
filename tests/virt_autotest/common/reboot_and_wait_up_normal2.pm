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
#package qa_run;
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

sub run() { 

	select_console('root-console');
	type_string("/sbin/reboot\n");
	reset_consoles;
	#wait_boot textmode => 1;
	sleep 5;
	my $timeout=300;
	assert_screen(["generic-destop", "generic-destop-virt"], $timeout);
	select_console('root-console');

}

sub test_flags {
    return {important => 1};
}

1;

