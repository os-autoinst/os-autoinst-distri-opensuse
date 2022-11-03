# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-bootloader
# Summary: Basic test for yast2 bootloader
# - Install yast2-bootloader
# - Launch yast2 bootloader
# - Handle missing package screen
# - Wait to yast2 to finish (initrd regenerated)
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use base 'y2_module_consoletest';
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use Utils::Backends qw(is_hyperv is_pvm_hmc);

sub run {
    my $self = shift;
    select_console 'root-console';

    # make sure yast2 bootloader module is installed
    zypper_call 'in yast2-bootloader';
    my $y2_opts = is_pvm_hmc() ? "--ncurses" : "";
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'bootloader', yast2_opts => $y2_opts);

    # YaST2 prompts user to install missing packages found during storage probing.
    # Otherwise YaST2 shows bootloader settings options
    $self->ncurses_filesystem_probing('test-yast2_bootloader-1');

    # OK => Close
    send_key "alt-o";
    # Our Hyper-V host & aarch64 is slow when initrd is being re-generated
    my $timeout = (is_hyperv || is_aarch64) ? 600 : 200;
    assert_screen([qw(yast2_bootloader-missing_package yast2_console-finished)], $timeout);
    if (match_has_tag('yast2_bootloader-missing_package')) {
        wait_screen_change { send_key 'alt-i'; };
    }
    wait_serial("$module_name-0", timeout => $timeout) || die "'yast2 bootloader' didn't finish";
    $self->clear_and_verify_console;
}

1;
