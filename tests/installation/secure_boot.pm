# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Make sure that we are in the installation overview with SB enabled
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    assert_screen "inst-overview-secureboot";

    $cmd{bootloader} = "alt-b" if check_var('VIDEOMODE', "text");
    send_key $cmd{change};    # Change
    send_key $cmd{bootloader};    # Bootloader

    # Is secure boot enabled?
    assert_screen "bootloader-secureboot-enabled";
    wait_screen_change { send_key $cmd{accept} };    # Accept
    send_key "alt-o";    # cOntinue
}

1;
