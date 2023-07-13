# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nest_vm
# Summary: Basics libvirtd test before and after migration, with a nested
# VM running or shutdown, performance of the nested vm is irrelevant as long
# as the service status is still enabled and active after migration.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use services::libvirtd;

sub run {
    select_console 'root-console';
    if (get_var('NESTED_VM_CHECK_BEFORE_MIGRATION')) {
        my %hash = (stage => 'after', service_type => 'Systemd', srv_pkg_name => 'libvirtd');
        services::libvirtd::full_libvirtd_check(%hash);
    }
    else {
        my %hash = (stage => 'before', service_type => 'Systemd', srv_pkg_name => 'libvirtd');
        services::libvirtd::full_libvirtd_check(%hash);
        set_var('NESTED_VM_CHECK_BEFORE_MIGRATION', 1);
        enter_cmd "reboot";
    }
}

sub post_run_hook {
    # Do nothing
}

1;

