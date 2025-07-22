# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Migration activation then reboot to perform migration.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use testapi;
use grub_utils 'grub_test';
use migration 'disable_installation_repos';
use power_action_utils 'power_action';
use utils 'zypper_call';

sub run {
    my $self = shift;

    select_console('root-console');

    assert_script_run("echo 'url: " . get_var('SCC_URL') . "' > /etc/SUSEConnect");

    my $repo_home = "http://download.suse.de/ibs/home:/fcrozat:/SLES16/SLE_\$releasever";
    my $repo_images = 'http://download.suse.de/ibs/home:/fcrozat:/SLES16/images/';
    zypper_call("ar -p 90 '$repo_home' home_sles16");
    zypper_call("ar -p 90 $repo_images home_images");

    # install the migration image and active it
    zypper_call("--gpg-auto-import-keys -n in suse-migration-sle16-activation");

    power_action('reboot', keepconsole => 1, first_reboot => 1);

    assert_screen('grub-menu-migration');
    assert_screen('migration-running');
    assert_screen('grub2', 400);
}

sub post_fail_hook {
    assert_screen('grub2', 300);
    send_key "ret";
    select_console 'root-console';
    upload_logs("/var/log/distro_migration.log", failok => 1);
}

1;
