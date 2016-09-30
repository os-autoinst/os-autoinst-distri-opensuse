# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run 'crash' utility on a kernel memory dump
#    Upstream kernel commit 8244062ef1 (v4.5), which got ingerited by SLE
#    from 11-SP4 to 12-SP2 fixed handling of /proc/kallsyms. This change
#    affected 'crash' utility, among other utilities.
#
#    Without
#    https://github.com/crash-utility/crash/commit/098cdab16dfa6a85e9dad2cad604dee14ee15f66
#    commit (v7.1.5) 'crash' crashed with:
#
#      crash: invalid structure member offset: module_num_symtab
#             FILE: kernel.c  LINE: 3421  FUNCTION: module_init()
#
#      [./crash] error trace: 472bde => 4e09e7 => 52a6ea => 52a679
#
#        52a679: OFFSET_verify.part.24+73
#        52a6ea: OFFSET_verify+42
#        4e09e7: module_init+1255
#        472bde: main_loop+238
#
#    https://bugzilla.suse.com/show_bug.cgi?id=977306
#    https://fate.suse.com/320844
#
#    This test enables kdump, dumps kernel memory and runs 'crash' on the
#    dump.
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub install_kernel_debuginfo {
    # kernel debug symbols are huge, this can take a while
    assert_script_run 'zypper ref; zypper -n -v in kernel-default-base-debuginfo kernel-default-debuginfo', 1200;
}

sub run() {
    select_console('root-console');

    script_run 'zypper -n in yast2-kdump kdump crash';

    script_run 'yast2 kdump', 0;

    # It seems that `toolchain/gcc5_Cpp_compilation.pm` spits some visual artifacts
    # (https://openqa.suse.de/tests/522356/file/video.ogv) which prevent needle match.
    # It's not enough to wait, we have to refresh the screen before check_screen or
    # assert_screen.
    wait_still_screen(20, 60);
    send_key 'ctrl-l';    # refresh the screen

    if (check_screen 'yast2-kdump-disabled') {
        send_key 'alt-u';    # enable kdump
    }

    send_key 'ctrl-l';       # refresh the screen
    assert_screen 'yast2-kdump-enabled';
    send_key 'alt-o';        # OK

    send_key 'ctrl-l';       # refresh the screen
    if (check_screen 'yast2-kdump-restart-info') {
        send_key 'alt-o';    # OK
    }

    # activate kdump
    wait_still_screen(10, 30);
    script_run 'reboot', 0;
    wait_boot;
    select_console 'root-console';

    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';

    # add debuginfo channels
    if (check_var('DISTRI', 'sle')) {
        my $url = "ftp://openqa.suse.de/" . get_required_var('REPO_SLES_DEBUG');
        assert_script_run "zypper ar -f $url SLES-Server-Debug";
        install_kernel_debuginfo;
        script_run 'zypper -n rr SLES-Server-Debug';
    }
    else {
        my $opensuse_debug_repos = 'repo-debug ';
        if (!check_var('VERSION', 'Tumbleweed')) {
            $opensuse_debug_repos .= 'repo-debug-update ';
        }
        assert_script_run "zypper -n mr -e $opensuse_debug_repos";
        install_kernel_debuginfo;
        assert_script_run "zypper -n mr -d $opensuse_debug_repos";
    }

    validate_script_output "yast2 kdump show 2>&1", sub { m/Kdump is enabled/ }, 90;

    # get dump
    script_run "echo c > /proc/sysrq-trigger", 0;

    # wait for system's reboot
    wait_boot;
    select_console 'root-console';

    my $suffix = check_var('ARCH', 'ppc64le') ? '' : '.gz';
    my $crash_cmd = 'echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`' . $suffix;
    assert_script_run "$crash_cmd";
    validate_script_output "$crash_cmd", sub { m/PANIC/ };
}

1;
# vim: set sw=4 et:
