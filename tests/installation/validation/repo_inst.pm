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
use testapi;

sub run {
    select_console 'install-shell';
    my $arch = get_var('ARCH');
    assert_script_run("grep -Pzo \"instsys url:(.|\\n)*disk:/boot/$arch/root\" /var/log/linuxrc.log");
}

1;
