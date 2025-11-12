# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: opensuse-migration-tool
# Summary: A command-line tool to simplify upgrades and migrations across openSUSE distributions
#              — including Leap, Tumbleweed, Slowroll, and even migrations from Leap to SLE.
#              - https://github.com/openSUSE/opensuse-migration-tool
#
# Maintainer: QE Core <qe-core@suse.de>

use base "opensusebasetest";
use testapi;
use utils qw(quit_packagekit zypper_call);
use power_action_utils 'power_action';

sub run {
    select_console 'root-console';
    quit_packagekit;
    zypper_call('in opensuse-migration-tool');

    enter_cmd "opensuse-migration-tool | tee /dev/$serialdev";
    assert_screen 'select_the_migration_target';
    my $migration_target_version = "target_version" . "-" . get_required_var('DISTRI') . "_" . get_required_var('VERSION');
    send_key_until_needlematch "$migration_target_version", 'down', 5, 2;
    send_key 'ret';
    send_key 'ret' if (check_screen 'disable_3rd_party_repositories', 10);
    wait_serial("Migration process completed.*A reboot is recommended", 2400) || die "migration failed, please check serial logs";

    power_action('reboot', textmode => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
