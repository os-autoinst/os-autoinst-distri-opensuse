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
use base 'y2logsstep';
use testapi;
use lockapi;
use utils;
use version_utils qw(is_caasp is_hyperv_in_gui);
use ipmi_backend_utils;

sub run {
    my ($self) = @_;
    return if get_var('REMOTE_CONTROLLER') || is_caasp || is_hyperv_in_gui;
    select_console 'install-shell';

    # check for right boot-device on s390x (zVM, DASD ONLY)
    if (check_var('BACKEND', 's390x') && !check_var('S390_DISK', 'ZFCP')) {
        if (script_run('lsreipl | grep 0.0.0150')) {
            die "IPL device was not set correctly";
        }
    }
    # while technically SUT has a different network than the BMC
    # we require ssh installation anyway
    if (check_var('BACKEND', 'ipmi') || check_var('BACKEND', 'spvm')) {
        use_ssh_serial_console;
        # set serial console for xen
        set_serial_console_on_xen('/mnt') if (get_var('XEN') || check_var('HOST_HYPERVISOR', 'xen'));
    }
    else {
        # avoid known issue in FIPS mode: bsc#985969
        $self->get_ip_address();
    }
    $self->save_upload_y2logs();
}

sub test_flags {
    return {fatal => 0};
}

1;
