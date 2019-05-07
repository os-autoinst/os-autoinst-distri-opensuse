# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Collect logs from the installation system just before we try to
#   reboot into the installed system
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;
use lockapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';
use ipmi_backend_utils;
use version_utils qw(is_sle is_s390x);

sub vnc_on_s390_workaround { # Really not a great place for this, but I did not find another.
    if ( is_s390x && (is_sle('15') || is_sle('15-SP1')) ) {
    unless (script_run("grep org.gnome.SettingsDaemon.Wacom /mnt/usr/share/gnome-session/sessions/gnome*")) {
        record_soft_failure 'bsc#1129412, Not possible to connect to VNC on installed system';
        assert_script_run("sed -i 's/org.gnome.SettingsDaemon.Wacom;//' /mnt/usr/share/gnome-session/sessions/gnome*");
        }
    }
}

sub run {
    my ($self) = @_;
    select_console 'install-shell';

    vnc_on_s390_workaround;
    # check for right boot-device on s390x (zVM, DASD ONLY)
    if (check_var('BACKEND', 's390x') && !check_var('S390_DISK', 'ZFCP')) {
        if (script_run('lsreipl | grep 0.0.0150')) {
            die "IPL device was not set correctly";
        }
    }
    # while technically SUT has a different network than the BMC
    # we require ssh installation anyway
    if (get_var('BACKEND', '') =~ /ipmi|spvm/) {
        use_ssh_serial_console;
        # set serial console for xen
        set_serial_console_on_vh('/mnt', '', 'xen') if (get_var('XEN') || check_var('HOST_HYPERVISOR', 'xen'));
        set_serial_console_on_vh('/mnt', '', 'kvm') if (check_var('HOST_HYPERVISOR', 'kvm') || check_var('SYSTEM_ROLE', 'kvm'));
        set_pxe_efiboot('/mnt') if check_var('ARCH', 'aarch64');
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
