# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST bootloader module.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use YaST::Module;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    ## Python2 is replaced by Python3 in sp4, generates a warning in UI as it cannot be kept.
    script_run('SUSEConnect -d -p sle-module-python2/15.3/x86_64; sleep 4') if check_var('VERSION', '15-SP4');
    script_run('for i in `SUSEConnect --list-extensions |grep Deactivate |awk \'{print $6}\' |cut -d/ -f 1`; do zypper in -yl $i-release ; done', 360);
    select_console 'x11';
    YaST::Module::open(module => 'migration', ui => 'qt');
    $testapi::distri->get_yast2_migration()->migration_target({target => 'SUSE Linux Enterprise Server 15 SP4 x86_64 including 8 modules and 1 extension'});
    save_screenshot;
}

1;
