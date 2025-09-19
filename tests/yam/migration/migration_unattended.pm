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
use utils qw(zypper_call reconnect_mgmt_console upload_folders);
use Utils::Architectures 'is_s390x';
use registration;

sub run {
    my $self = shift;

    select_console('root-console');

    assert_script_run("echo 'url: " . get_var('SCC_URL') . "' > /etc/SUSEConnect");

    my $repo_server = get_var('REPO_MIRROR_HOST', 'download.suse.de');
    my $repo_home = "http://" . $repo_server . "/ibs/home:/fcrozat:/SLES16/SLE_\$releasever";
    my $repo_images = 'http://' . $repo_server . '/ibs/home:/fcrozat:/SLES16/images/';
    zypper_call("ar --refresh -p 90 '$repo_home' home_sles16");
    zypper_call("ar --refresh -p 90 $repo_images home_images");

    # install the migration image and active it
    my $migration_tool = is_s390x() ? 'SLES16-Migration' : 'suse-migration-sle16-activation';
    zypper_call("--gpg-auto-import-keys -n in $migration_tool");

    # disable repos of the product to migrate from due to proxySCC is not serving SLES 15 SP*
    my $version = get_var('VERSION_UPGRADE_FROM');
    $version =~ s/-/_/;
    script_run('for s in $(zypper -t ls | grep _Module_' . "$version" . ' | sed -e \'s,|.*,,g\'); do zypper modifyservice --disable $s; done');

    # deacivate unwanted/unsupported extensions before doing migration
    if (get_var('SCC_SUBTRACTIONS')) {
        foreach (split(',', get_var('SCC_SUBTRACTIONS'))) {
            my $extension = get_addon_fullname($_);
            remove_suseconnect_product($extension);
        }
    }

    # upload logs to know system state before migration
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/');

    if (is_s390x()) {
        enter_cmd '/usr/sbin/run_migration';
        reconnect_mgmt_console;
    } else {
        power_action('reboot', textmode => 1, keepconsole => 1, first_reboot => 1);
        assert_screen([qw(grub-menu-migration migration-running)]);
        assert_screen('grub2', 400);
    }
}

sub post_fail_hook {
    assert_screen('grub2', 300);
    send_key "ret";
    select_console 'root-console';
    upload_logs("/var/log/distro_migration.log", failok => 1);
}

1;
