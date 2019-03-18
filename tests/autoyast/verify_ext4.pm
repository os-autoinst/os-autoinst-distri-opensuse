# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate autoyast_ext4 profile.
#          * Verify registration (only 15+)
#          * Verify partitioning: ext4 and swap
#          * Verify users
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use base 'basetest';
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub verify_registration {
    my $output = script_output 'SUSEConnect --list-extensions';
    unless ($output =~ /Basesystem.*Activated/ && $output =~ /Server Applications.*Activated/) {
        die 'Registered system does not contains Basesystem and/or Applications Server';
    }
}

sub verify_partitioning {
    assert_script_run 'findmnt -S /dev/vda2 | grep "/.*ext4"';                    # generic search
    assert_script_run 'findmnt -s | grep "swap\s\+UUID.*swap"';                   # search for swap only in /etc/fstab
    assert_script_run 'findmnt -s | grep "/\s\+UUID.*ext4\s\+acl,user_xattr"';    # Search for attr. only in /etc/fstab
}

sub verify_user {
    assert_script_run 'grep "bernhard:x:1000:100:Bernhard M. Wiedemann:/home/bernhard:/bin/bash" /etc/passwd';
}

sub run {
    select_console 'root-console';
    verify_registration if is_sle('15+');
    verify_partitioning;
    verify_user;
}

1;
