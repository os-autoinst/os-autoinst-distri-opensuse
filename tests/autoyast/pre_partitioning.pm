# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Performs disk pre-partition before AutoYaST installation
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';
use bootloader_setup 'create_encrypted_part';

sub run {
    my $test_data = get_test_suite_data();
    assert_screen 'linuxrc-start-shell-before-installation', 60;
    create_encrypted_part(disk => $test_data->{device}, luks_type => 'luks2');
    type_string "exit\n";
}

1;

