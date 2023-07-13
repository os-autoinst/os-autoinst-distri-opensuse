# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Performs disk pre-partition before AutoYaST installation
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';
use bootloader_setup 'create_encrypted_part';

sub run {
    my $test_data = get_test_suite_data();
    assert_screen 'linuxrc-start-shell-before-installation', 120;
    create_encrypted_part(disk => $test_data->{disks}[0]{name}, luks_type => 'luks2');
    enter_cmd "exit";
}

1;
