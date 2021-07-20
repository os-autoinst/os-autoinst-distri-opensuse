# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: nest_vm
# Summary: Basics libvirtd test before and after migration, with a nested
# VM running or shutdown, performance of the nested vm is irrelevant as long
# as the service status is still enabled and active after migration.
# Maintainer: wegao@suse.com

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

