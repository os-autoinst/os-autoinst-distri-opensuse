# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package update_package;
# Summary: update_package: Update all packages and use real repo as guest installation source before test.
# Maintainer: John <xgwang@suse.com>

use strict;
use warnings;
use testapi;
use base "virt_autotest_base";
use virt_utils;
use ipmi_backend_utils;

sub update_package {
    my $self           = shift;
    my $test_type      = get_var('TEST_TYPE', 'Milestone');
    my $update_pkg_cmd = "source /usr/share/qa/virtautolib/lib/virtlib;update_virt_rpms";
    my $ret;
    if ($test_type eq 'Milestone') {
        $update_pkg_cmd = $update_pkg_cmd . " off on off";
    }
    else {
        $update_pkg_cmd = $update_pkg_cmd . " off off on";
    }

    $update_pkg_cmd = $update_pkg_cmd . " 2>&1 | tee /tmp/update_virt_rpms.log ";
    $ret            = $self->execute_script_run($update_pkg_cmd, 7200);
    upload_logs("/tmp/update_virt_rpms.log");
    save_screenshot;
    if ($ret !~ /Need to reboot system to make the rpms work/m) {
        die " Update virt rpms fail, going to terminate following test!";
    }

}

sub run {
    my $self = shift;
    $self->update_package();
    set_serial_console_on_vh('', '', 'xen') if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen"));
    set_serial_console_on_vh('', '', 'kvm') if (check_var("HOST_HYPERVISOR", "kvm") || check_var("SYSTEM_ROLE", "kvm"));
    update_guest_configurations_with_daily_build();
}


sub test_flags {
    return {fatal => 1};
}

1;
