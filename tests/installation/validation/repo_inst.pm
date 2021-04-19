# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that instsys and install urls match the boot parameters.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use utils 'get_netboot_mirror';
use testapi;


sub run {
    assert_screen 'startshell', 90;
    my $arch = get_var('ARCH');
    assert_script_run("grep -Pzo \"instsys url:(.|\\n)*disk:/boot/$arch/root\" /var/log/linuxrc.log");
    my $mirror = get_netboot_mirror;
    assert_script_run("grep -Pzo \"install url:(.|\\n)*$mirror\" /var/log/linuxrc.log");
    enter_cmd "exit";
}

1;
