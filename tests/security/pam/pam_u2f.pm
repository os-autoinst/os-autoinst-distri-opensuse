# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update pam_u2f to 1.1.1 (or later)
#          Add support to FIDO2 (move from libu2f-host+libu2f-server to libfido2)
#          Add support to User Verification
#          Add support to PIN Verification
#          Add support to Resident Credentials
#          Add support to SSH credential format
#          This adds support for FIDO2 (yubikey or other)
#          with pam and provides additional verifications (User, PIN)
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#104181 tc#1769990

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use base 'consoletest';
use utils qw(zypper_call package_upgrade_check);

sub run {
    select_console('root-console');
    zypper_call('in pam_u2f');

    # Package version check
    my $pkg_list = {'pam_u2f' => '1.1.1'};
    zypper_call("in " . join(' ', keys %$pkg_list));
    package_upgrade_check($pkg_list);

    # Package change log check
    my $change_log = script_output('rpm -q pam_u2f --changelog');
    if ($change_log =~ m/Add support to FIDO2/
        && $change_log =~ m/Add support to User Verification/
        && $change_log =~ m/Add support to PIN Verification/
        && $change_log =~ m/Add support to Resident Credentials/
        && $change_log =~ m/Add support to SSH credential format/)
    {
        record_info('All required patches are set');
    }
    else {
        die('Not all required patches are set, please check with developer');
    }

    # 'pamu2fcfg' command test, we don't have available yubikey
    # However, we can still check this command can work
    validate_script_output('pamu2fcfg 2>&1 || true', sub { m/No device found. Aborting/ });
}

sub test_flags {
    return {always_rollback => 1};
}

1;
