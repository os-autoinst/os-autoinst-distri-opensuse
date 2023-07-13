# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable Live Patching module in SLE Micro
# Maintainer: qa-c@suse.de

use base "consoletest";
use strict;
use warnings;
use testapi;
use transactional;
use utils qw(zypper_call);

sub run {
    select_console 'root-console';

    my $arch = get_required_var('ARCH');
    my $regcode = get_required_var('SCC_REGCODE_LIVE');
    my $lp_version = get_required_var('LIVE_PATCHING_VERSION');
    my $extensions = script_output('SUSEConnect --list-extensions');

    record_info('Extensions', $extensions);

    die("Live Patching module shouldn't be enabled by default") if ($extensions =~ m/Live Patching.*Activated/);

    record_info('Register', 'Registering module "sle-module-live-patching"');
    trup_call("register -p sle-module-live-patching/$lp_version/$arch -r $regcode");
    check_reboot_changes;
    $extensions = script_output('SUSEConnect --list-extensions');
    record_info('SUSEConnect', script_output('SUSEConnect --status-text'));
    record_info('Extensions', $extensions);

    die('There was a problem activating the Live Patching module') unless ($extensions =~ m/Live Patching.*Activated/);
    zypper_call('--gpg-auto-import-keys ref');

    # ensure sle-module-live-patching-release is installed
    assert_script_run('rpm -q sle-module-live-patching-release');
    if (script_output('zypper patterns --installed-only') !~ 'lp_sles') {
        record_info('Pattern', 'Installing pattern lp_sles');
        trup_call('pkg install -t pattern lp_sles');
        check_reboot_changes;
    }
}

1;
