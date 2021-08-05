# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Collect logs from the installation system just before we try to
#   reboot into the installed system
# - If BACKEND is s390x or S390_DISK is not ZFCP, run "lsreipl | grep $dasd_path"
# to check IPL device
# - If BACKEND is ipmi or spvm, set serial console type depending, HYPERVISOR TYPE (xen,
# kvm) or ARCH (aarch64)
# - Otherwise
#   - Get ip for network interface
#   - Get /etc/resolv.conf contents
#   - Save screenshot
# - Upload yast2 installation network logs
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';
use version_utils 'is_sle';
use ipmi_backend_utils;

sub run {
    my ($self) = @_;
    my $dasd_path = get_var('DASD_PATH', '0.0.0150');
    select_console 'install-shell';

    # check for right boot-device on s390x (zVM, DASD ONLY)
    if (check_var('BACKEND', 's390x') && !check_var('S390_DISK', 'ZFCP')) {
        if (script_run("lsreipl | grep $dasd_path")) {
            die "IPL device was not set correctly";
        }
    }
    # while technically SUT has a different network than the BMC
    # we require ssh installation anyway
    if (get_var('BACKEND', '') =~ /ipmi|spvm/) {
        use_ssh_serial_console;
        # set serial console for xen and kvm of SLE hosts
        # for openSUSE TW, it is set in other place where after kvm/xen patterns are installed
        if (is_sle) {
            set_serial_console_on_vh('/mnt', '', 'xen') if (get_var('XEN') || check_var('HOST_HYPERVISOR', 'xen'));
            set_serial_console_on_vh('/mnt', '', 'kvm') if (check_var('HOST_HYPERVISOR', 'kvm') || check_var('SYSTEM_ROLE', 'kvm'));
            adjust_for_ipmi_xen('/mnt')                 if (get_var('REGRESSION') && (get_var('XEN') || check_var('HOST_HYPERVISOR', 'xen')));
            set_pxe_efiboot('/mnt')                     if check_var('ARCH', 'aarch64');
        }
    }
    else {
        # avoid known issue in FIPS mode: bsc#985969
        $self->get_ip_address();
    }

    # We don't change network setup here, so should work
    # We don't parse logs unless it's detect_yast2_failures scenario
    $self->save_upload_y2logs(no_ntwrk_recovery => 1, skip_logs_investigation => !get_var('ASSERT_Y2LOGS'));
}

sub test_flags {
    return {fatal => 0};
}

1;
