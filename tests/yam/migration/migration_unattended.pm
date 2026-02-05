# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Migration activation then reboot to perform migration.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;
use grub_utils 'grub_test';
use migration 'disable_installation_repos';
use power_action_utils 'power_action';
use utils qw(zypper_call reconnect_mgmt_console upload_folders);
use Utils::Architectures 'is_s390x';
use registration;

sub run {
    my $self = shift;

    select_console('root-console');

    # install the migration image and active it
    my $migration_tool = is_s390x ? 'SLES16-Migration' : 'suse-migration-sle16-activation';
    zypper_call("--gpg-auto-import-keys -n in $migration_tool");

    # disable repos of the product to migrate from due to proxySCC is not serving SLES 15 SP*
    my $version = get_var('VERSION_UPGRADE_FROM');
    $version =~ s/-/_/;

    # deacivate unwanted/unsupported extensions before doing migration
    if (get_var('SCC_SUBTRACTIONS')) {
        foreach my $addon (split(',', get_var('SCC_SUBTRACTIONS'))) {
            my $extension = get_addon_fullname($addon);
            # NVIDIA Compute is not versioned by SP
            remove_suseconnect_product($extension, (($addon eq 'nvidia') ? '15' : ()));
        }
    }

    # upload logs to know system state before migration
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');

    if (is_s390x) {
        assert_script_run("echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf");
        enter_cmd '/usr/sbin/run_migration';
        reset_consoles;
        reconnect_mgmt_console(timeout => 600);
    } else {
        # disable timeout for migration grub menu
        assert_script_run("sed -i 's/set timeout=[0-9]*/set timeout=-1/' /etc/grub.d/99_migration");
        assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
        power_action('reboot', textmode => 1, keepconsole => 1, first_reboot => 1);
        assert_screen('grub-menu-migration', 120);
        send_key 'ret';
        assert_screen('migration-running', 60);
        assert_screen('grub2', 1000);
    }
}

sub post_fail_hook {
    assert_screen('grub2', 300);
    send_key "ret";
    select_console 'root-console';
    upload_logs("/var/log/distro_migration.log", failok => 1);
}

1;
