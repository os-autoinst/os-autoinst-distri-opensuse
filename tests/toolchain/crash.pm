# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run 'crash' utility on a kernel memory dump
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub install_kernel_debuginfo {
    # list installed kernels
    assert_script_run 'rpmquery -a kernel-default*';
    # kernel debug symbols are huge, this can take a while
    assert_script_run 'zypper ref; zypper -n -v in kernel-default-debuginfo', 1200;
}

sub run() {
    select_console('root-console');

    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';

    script_run 'zypper -n in yast2-kdump kdump crash';

    # add debuginfo channels
    if (check_var('DISTRI', 'sle')) {
        # debuginfos for kernel has to be installed from build-specific directory on FTP.
        # To get the right directory we modify content of REPO_0 variable, e.g.:
        #   SLE-12-SP2-Server-DVD-x86_64-Build2188-Media1 -> SLE-12-SP2-SERVER-POOL-x86_64-Build2188-Media3
        my $sles_debug_repo = get_var('REPO_0') =~ s/(Server|Desktop)/\U$1\E/r;
        $sles_debug_repo =~ s/DVD/POOL/;
        $sles_debug_repo =~ s/Media1/Media3/;
        my $url = "ftp://openqa.suse.de/$sles_debug_repo";
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

    # restart to get rid of potential screen disruptions from previous test
    script_run 'reboot', 0;
    wait_boot;
    select_console 'root-console';

    # activate kdump
    script_run 'yast2 kdump', 0;
    if (check_screen 'yast2-kdump-disabled') {
        send_key 'alt-u';    # enable kdump
    }

    assert_screen 'yast2-kdump-enabled';
    send_key 'alt-o';        # OK

    if (check_screen 'yast2-kdump-restart-info') {
        send_key 'alt-o';    # OK
    }

    wait_still_screen(10, 30);
    script_run 'reboot', 0;
    wait_boot;
    select_console 'root-console';

    # make sure kdump is enabled after reboot
    validate_script_output "yast2 kdump show 2>&1", sub { m/Kdump is enabled/ }, 90;

    # get dump
    script_run "echo c > /proc/sysrq-trigger", 0;

    # wait for system's reboot
    wait_boot;
    select_console 'root-console';

    # all but PPC64LE arch's vmlinux images are gzipped
    my $suffix = check_var('ARCH', 'ppc64le') ? '' : '.gz';
    my $crash_cmd = "echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`$suffix";
    assert_script_run "$crash_cmd";
    validate_script_output "$crash_cmd", sub { m/PANIC/ };
}

1;
# vim: set sw=4 et:
