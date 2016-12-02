# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: proxymode_init_pxe_install: Initialize pxe and start to install special product
# Maintainer: John <xgwang@suse.com>

use strict;
use warnings;
use testapi;
use base "proxymode";

sub run() {
    my $self         = shift;
    my $ipmi_machine = get_var("IPMI_HOSTNAME");
    my $autoyast     = get_var("AUTOYAST_FILE");
    my $image_path   = get_var("HOST_IMG_URL");

    die "There is no ipmi ip address defined variable IPMI_HOSTNAME"       unless $ipmi_machine;
    die "There is no re-install product cmd defined variable HOST_IMG_URL" unless $image_path;
    die "There is no autoyase file defined variable AUTOYAST_FILE"         unless $autoyast;
    ## Login to command line of pxe management
    $self->connect_slave($ipmi_machine);
    $self->restart_host($ipmi_machine);
    assert_screen "proxy_virttest-pxe", 300;
    wait_idle 3;
    send_key_until_needlematch "proxy_virttest-pxe-edit-prompt", "esc", 10, 5;
    wait_still_screen 5;
    # Execute installation command on pxe management cmd console
    my $type_speed = 20;
    type_string ${image_path} . " ", $type_speed;
    type_string "console=ttyS1,115200 ", $type_speed;
    type_string "console=tty ",          $type_speed;
    type_string "autoyast=" . $autoyast, $type_speed;
    wait_still_screen 5;
    send_key 'ret';
    save_screenshot;
    $self->check_prompt_for_boot();
}

sub test_flags {
    return {fatal => 1};
}

1;
