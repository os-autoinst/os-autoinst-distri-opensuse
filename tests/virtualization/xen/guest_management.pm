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

use base "x11test";
use xen;
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');

    x11_start_program('xterm');
    send_key 'super-up';

    record_info "SHUTDOWN", "Shut all guests down";
    assert_script_run "ssh root\@$hypervisor 'virsh shutdown $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

    record_info "START", "Start all guests";
    assert_script_run "ssh root\@$hypervisor 'virsh start $_'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

    record_info "REBOOT", "Reboot all guests";
    sleep 60;
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
    clear_console;

    wait_screen_change { send_key 'alt-f4'; };
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

