# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Nothing change and accept kdump options.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;

use cfg_files_utils qw(validate_cfg_file);
use scheduler qw(get_test_suite_data);
use testapi qw(save_screenshot select_console);
use utils qw(systemctl zypper_call);
use YaST::Module;

sub run {
    my $startup = $testapi::distri->get_kdump_startup();

    select_console('root-console');
    zypper_call('in kdump');

    YaST::Module::open(module => 'kdump', ui => 'ncurses');

    $startup->get_navigation->ok();
    save_screenshot;

    select_console('root-console');
    systemctl('is-enabled kdump');
    validate_cfg_file(get_test_suite_data()->{config_files});
}

1;
