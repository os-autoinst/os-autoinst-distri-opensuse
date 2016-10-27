# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;
use virt_autotest_base;

use base "proxymodeapi";

sub run() {
    my $self = shift;

    $self->restart_host();
    ## Login to command line of pxe management
    $self->connect_slave();
    assert_screen "proxy_virttest-pxe", 300;
    send_key_until_needlematch "proxy_virttest-pxe-edit-prompt", "esc", 10, 5;
    sleep 5;

    # Execute installation command on pxe management cmd console
    my $type_speed = 20;
    my $image_path = get_var("HOST_IMG_URL");

    type_string ${image_path} . " ", $type_speed;
    type_string "vga=791 ",                                                              $type_speed;
    type_string "Y2DEBUG=1 ",                                                            $type_speed;
    type_string "video=1024x768-16 ",                                                    $type_speed;
    type_string "console=ttyS1,115200n81 ",                                              $type_speed;    # to get crash dumps as text
    type_string "console=tty ",                                                          $type_speed;
    type_string "autoyast=http://147.2.207.67/install/autoinst/autoinst_ipmiserver.xml", $type_speed;
    send_key 'ret';

    $self->check_prompt_for_boot();
}

sub test_flags {
    return {fatal => 1};
}

1;

