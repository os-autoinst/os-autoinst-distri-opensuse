# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Migration activation then reboot to perform migration.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use registration 'register_addons_cmd';
use utils 'zypper_call';
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    select_console('root-console');

    zypper_call("in sles-release");
    my $repo_home = "http://download.suse.de/ibs/home:/fcrozat:/SLES16/SLE_\$releasever";
    my $repo_images = 'http://download.suse.de/ibs/home:/fcrozat:/SLES16/images/';
    assert_script_run("zypper ar -p 90 '$repo_home' home_sles16");
    assert_script_run("zypper ar -p 90 $repo_images home_images");

    # install the migration image and active it
    zypper_call("--gpg-auto-import-keys -n in suse-migration-sle16-activation");

    power_action('reboot', keepconsole => 1, first_reboot => 1);

    record_info 'Handle GRUB';
    grub_test();
    $self->wait_boot(bootloader_time => 300, textmode => 1, ready_time => 600);
}

1;
