# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: apparmor-parser patterns-base-apparmor apparmor-utils
# Summary: Package for apparmor service tests
#
# Maintainer: Huajian Luo <hluo@suse.com>

package services::apparmor;
use base "apparmortest";
use testapi;
use utils;
use version_utils 'is_sle';
use warnings;
use strict;

sub install_service {
    # apparmor need be installed by pattern
    zypper_call 'in -t pattern apparmor';
}

sub enable_service {
    # SLE12-SP2 doesn't support systemctl to enable apparmor
    if (is_sle('12-SP3+', get_var('HDDVERSION'))) {
        systemctl 'enable apparmor', timeout => 180;
    }
}

sub start_service {
    systemctl 'start apparmor';
}

# check service is running and enabled
sub check_service {
    # SLE12-SP2 doesn't support systemctl to enable apparmor
    if (is_sle('12-SP3+', get_var('HDDVERSION'))) {
        # Do double check to avoid performance issue
        my $ret = script_run 'systemctl --no-pager is-enabled apparmor.service';
        if ($ret) {
            # If failed try sync and then check again
            assert_script_run 'sync';
            systemctl 'is-enabled apparmor.service';
        }
    }
    systemctl 'is-active apparmor';
}

# check aa_status
sub check_aa_status {
    my ($self) = @_;
    diag 'check aa_status.';

    validate_script_output "aa-status", sub {
        m/
        module\ is\ loaded.*
        profiles\ are\ loaded.*
        profiles\ are\ in\ enforce\ mode.*
        profiles\ are\ in\ complain\ mode.*
        processes\ are\ in\ enforce\ mode.*
        processes\ are\ in\ complain\ mode.*
        processes\ are\ unconfined/sxx
    };
}

# check aa_enforce
sub check_aa_enforce {
    my ($self) = @_;
    diag 'check aa_enforce.';

    my $executable_name = "/usr/sbin/nscd";
    my $profile_name = "usr.sbin.nscd";
    my $named_profile = "";
    systemctl('restart apparmor');

    # Recalculate profile name in case
    $named_profile = $self->get_named_profile($profile_name);

    validate_script_output "aa-disable $executable_name", sub {
        m/Disabling.*nscd/;
    }, timeout => 180;

    # Check if /usr/sbin/ntpd is really disabled
    die "$executable_name should be disabled"
      if (script_run("aa-status | sed 's/[ \t]*//g' | grep -x $named_profile") == 0);

    validate_script_output "aa-enforce $executable_name", sub {
        m/Setting.*nscd to enforce mode/;
    }, timeout => 180;

    # Check if $named_profile is in "enforce" mode
    $self->aa_status_stdout_check($named_profile, "enforce");
}

# check aa_complain
sub check_aa_complain {
    my ($self) = @_;
    diag 'check aa_complain.';
    my $aa_tmp_prof = "/tmp/apparmor.d";

    # Test both situation for default profiles location and the location
    # specified with '-d'
    my @aa_complain_cmds = ("aa-complain usr.sbin.nscd", "aa-complain -d $aa_tmp_prof usr.sbin.nscd");

    systemctl('restart apparmor');

    assert_script_run "cp -r /etc/apparmor.d $aa_tmp_prof";

    foreach my $cmd (@aa_complain_cmds) {
        validate_script_output $cmd, sub {
            m/Setting.*nscd to complain mode/s;
        }, timeout => 180;

        # Restore to the enforce mode
        assert_script_run "aa-enforce usr.sbin.nscd";
    }

    # Clean Up
    assert_script_run "rm -rf $aa_tmp_prof";
}

#
# check apparmor function
# we check aa_status, aa_enforce and aa_complain
# for apparmor function check.
#
sub check_function {
    my ($self) = apparmortest->new();

    select_console 'root-console';

    check_aa_status($self);
    check_aa_enforce($self);
    check_aa_complain($self);
}

# check apparmor service before and after migration
# stage is 'before' or 'after' system migration.
sub full_apparmor_check {
    my (%hash) = @_;
    my $stage = $hash{stage};
    if ($stage eq 'before') {
        install_service();
        enable_service();
        start_service();
    }
    check_service();
    check_function();
}

1;
