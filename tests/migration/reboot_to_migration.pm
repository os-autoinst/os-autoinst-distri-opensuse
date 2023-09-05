# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Reboot machine to perform upgrade
#       Just trigger reboot action, afterwards tests will be
#       incepted by later test modules, such as tests in
#       load_boot_tests or wait_boot in setup_zdup.pm
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi qw(select_console set_var assert_script_run send_key assert_screen);
use Utils::Architectures;
use Utils::Backends 'is_pvm';
use power_action_utils 'power_action';
use version_utils;
use utils qw(quit_packagekit wait_for_purge_kernels);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Mark the hdd has been patched
    set_var('PATCHED_SYSTEM', 1);

    assert_script_run "sync", 300;
    power_action('reboot', textmode => 1, keepconsole => 1);

    assert_screen('inst-bootmenu', 300) unless (is_s390x || is_pvm);

    send_key 'up' if is_x86_64;
}

sub pre_run_hook {
    quit_packagekit;
    wait_for_purge_kernels;
}

1;

