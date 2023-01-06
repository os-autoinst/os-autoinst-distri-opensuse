# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test module to validate YaST Firstboot configuration settings are
# applied to the SUT.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package validate_yast2_firstboot_configuration;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub assert_user_exist {
    my ($username) = @_;
    assert_script_run("id $username",
        fail_message => "User $username not found in the system, though it" .
          " is expected to be created by YaST Firstboot");
}

sub pre_run_hook {
    my ($self) = @_;
    select_console 'root-console';
    $self->SUPER::pre_run_hook;
}

sub run {
    my $test_data = get_test_suite_data()->{users};
    assert_user_exist($test_data->{username});
}

1;
