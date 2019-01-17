# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test basic VM guest management
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "consoletest";
use xen;
use strict;
use testapi;
use utils;

sub run {
    my ($self)     = @_;
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');
    my $domain     = get_required_var('QAM_XEN_DOMAIN');

    record_info "SHUTDOWN", "Shut all guests down";
    assert_script_run "ssh root\@$hypervisor 'virsh shutdown $_'" foreach (keys %xen::guests);
    for (my $i = 0; $i <= 120; $i++) {
        if (script_run("ssh root\@$hypervisor 'virsh list --all | grep -v Domain-0 | grep running'") == 1) {
            last;
        }
        sleep 1;
    }

    record_info "START", "Start all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh start $_'" foreach (keys %xen::guests);
    foreach my $guest (keys %xen::guests) {
        for (my $i = 0; $i <= 60; $i++) {
            if (script_run("ssh root\@$guest.$domain hostname -f") == 0) {
                last;
            }
            sleep 1;
        }
    }

    record_info "REBOOT", "Reboot all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh reboot $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

    record_info "AUTOSTART ENABLE", "Enable autostart for all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh autostart $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

    record_info "AUTOSTART DISABLE", "Disable autostart for all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh autostart --disable $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

    record_info "SUSPEND", "Suspend all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh suspend $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

    record_info "RESUME", "Resume all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh resume $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";
    foreach my $guest (keys %xen::guests) {
        for (my $i = 0; $i <= 60; $i++) {
            if (script_run("ssh root\@$guest.$domain hostname -f") == 0) {
                last;
            }
            sleep 1;
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

