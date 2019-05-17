# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run 'crash' utility on a kernel memory dump
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use kdump_utils;
use version_utils 'is_sle';
use registration;

sub run {
    my ($self) = @_;
    select_console('root-console');

    # preparation for crash test
    if (is_sle '15+') {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
    }
    prepare_for_kdump;
    activate_kdump;

    # restart to activate kdump
    power_action('reboot', keepconsole => check_var('BACKEND', 'spvm'));
    reconnect_mgmt_console if check_var('BACKEND', 'spvm');
    $self->wait_boot;
    select_console 'root-console';

    if (check_var('ARCH', 'ppc64le') || check_var('ARCH', 'ppc64')) {
        if (script_run('kver=$(uname -r); kconfig="/boot/config-$kver"; [ -f $kconfig ] && grep ^CONFIG_RELOCATABLE $kconfig')) {
            record_soft_failure 'poo#49466 -- No kdump if no CONFIG_RELOCATABLE in kernel config';
            return 1;
        }
    }

    # often kdump could not be enabled: bsc#1022064
    return 1 unless kdump_is_active;
    do_kdump;
    if (get_var('FADUMP')) {
        reconnect_mgmt_console;
        assert_screen 'grub2', 180;
        wait_screen_change { send_key 'ret' };
    }
    elsif (check_var('BACKEND', 'spvm')) {
        reconnect_mgmt_console;
    }
    else {
        power_action('reboot', observe => 1, keepconsole => 1);
    }
    # Wait for system's reboot; more time for Hyper-V as it's slow.
    $self->wait_boot(bootloader_time => check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 200 : undef);
    select_console 'root-console';

    # all but PPC64LE arch's vmlinux images are gzipped
    my $suffix = check_var('ARCH', 'ppc64le') ? '' : '.gz';
    assert_script_run 'find /var/crash/';

    my $crash_cmd = "echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`$suffix";
    validate_script_output "$crash_cmd", sub { m/PANIC:\s([^\s]+)/ }, 600;
}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
