# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that instsys and install urls match the boot parameters.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use utils 'get_netboot_mirror';
use testapi;


sub run {
    assert_screen 'startshell', 180;
    my $arch = get_var('ARCH');
    assert_script_run("grep -Pzo \"instsys url:(.|\\n)*disk:/boot/$arch/root\" /var/log/linuxrc.log");
    my $mirror = get_netboot_mirror;
    assert_script_run("grep -Pzo \"install url:(.|\\n)*$mirror\" /var/log/linuxrc.log");
    enter_cmd "exit";
}

1;
