# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test module to validate YaST Firstboot configuration settings are
# applied to the SUT.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package validate_yast2_firstboot_configuration;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub assert_user_exist {
    my ($username) = @_;
    assert_script_run("id $username", fail_message => "User $username not found in the system, though it is expected to be created by YaST Firstboot");
}

sub pre_run_hook {
    select_console 'root-console';
}

sub run {
    assert_user_exist(get_var('YAST2_FIRSTBOOT_USERNAME'));
}

1;
