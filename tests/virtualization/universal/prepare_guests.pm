# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: libvirt-client iputils nmap xen-tools
# Summary: Installation of HVM and PV guests
# Maintainer: Pavel Dostál <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    # Ensure additional package is installed
    zypper_call '-t in libvirt-client iputils nmap';

    assert_script_run "mkdir -p /var/lib/libvirt/images/xen/";

    if (is_sle('<=12-SP1')) {
        script_run "umount /home";
        assert_script_run qq(sed -i 's/\\/home/\\/var\\/lib\\/libvirt\\/images\\/xen/g' /etc/fstab);
        script_run "mount /var/lib/libvirt/images/xen/";
    }

    assert_script_run "curl -f -v " . data_url("virt_autotest/libvirtd.conf") . " >> /etc/libvirt/libvirtd.conf";
    systemctl 'restart libvirtd';

    if (script_run("virsh net-list --all | grep default") != 0) {
        assert_script_run "curl " . data_url("virt_autotest/default_network.xml") . " -o ~/default_network.xml";
        assert_script_run "virsh net-define --file ~/default_network.xml";
    }
    assert_script_run "virsh net-start default || true", 90;
    assert_script_run "virsh net-autostart default",     90;

    # Show all guests
    assert_script_run 'virsh list --all';
    wait_still_screen 1;

    # Disable bash monitoring, so the output of completed background jobs doesn't confuse openQA
    script_run("set +m");

    # Install every defined guest
    create_guest $_, 'virt-install' foreach (values %virt_autotest::common::guests);

    ## Our test setup requires guests to restart when the machine is rebooted.
    ## Ensure every guest has <on_reboot>restart</on_reboot>
    foreach my $guest (keys %virt_autotest::common::guests) {
        if (script_run("! virsh dumpxml $guest | grep 'on_reboot' | grep -v 'restart'") != 0) {
            record_info("$guest bsc#1153028", "Setting on_reboot=restart failed for $guest");
        }
    }

    script_run 'history -a';
    assert_script_run('cat ~/virt-install*', 30);
    script_run('xl dmesg |grep -i "fail\|error" |grep -vi Loglevel') if (is_xen_host());
    collect_virt_system_logs();
}

sub post_fail_hook {
    my ($self) = @_;
    collect_virt_system_logs();
    $self->SUPER::post_fail_hook;
}

1;
