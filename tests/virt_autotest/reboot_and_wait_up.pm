# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reboot_and_wait_up;
# G-Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# G-Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;
use login_console;

use base "proxymodeapi";

sub switch_xen() {
    my $self = shift;

    assert_script_run("clear;/usr/share/qa/virtautolib/tools/switch2_xen.sh", 1800);
    sleep 5;

}

sub reboot_and_wait_up() {
    my $self           = shift;
    my $reboot_timeout = shift;

    wait_idle 1;
    select_console('root-console');

    if (get_var("PROXY_VIRT_AUTOTEST")) {
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            $self->switch_xen();
        }
        type_string("/sbin/reboot\n");
        $self->check_prompt_for_boot($reboot_timeout);
    }
    else {
        wait_idle 1;
        type_string("/sbin/reboot\n");
        wait_idle 1;
        reset_consoles;
        wait_idle 1;
        &login_console::login_to_console($reboot_timeout);
    }
}

1;

