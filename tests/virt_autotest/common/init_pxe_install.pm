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

	# Wait initial screen for ipmi bootloader
	assert_screen "virttest-bootload", 60;
	
	# Wait the second screen for ipmi bootloader
        send_key_until_needlematch "virttest-bootloader2", "f12", 3, 60;

	# Wait pxe management screen
        send_key_until_needlematch "virttest-pxe-management", "f12", 200, 1;

        # Login to command line of pxe management
	send_key_until_needlematch "virttest-prompt-pxe-install", "esc", 60, 1;

	my $type_speed = 20;
	my $loader_name = "sles-12-sp2-alpha2";

	my $image_path = get_var("HOST_IMG_URL");
	
	# Execute installation command on pxe management cmd console
	type_string  ${image_path} . "\n", $type_speed;
	#type_string "vga=791 ",                   $type_speed;
	#type_string "Y2DEBUG=1 ",                 $type_speed;
	#type_string "video=1024x768-16 ",         $type_speed;
	#type_string "console=ttyS1,115200 ", $type_speed;    # to get crash dumps as text
	#type_string "console=tty ",               $type_speed;  
	#send_key 'ret'
	
	save_screenshot;
}

sub test_flags {
    return {important => 1};
}

1;

