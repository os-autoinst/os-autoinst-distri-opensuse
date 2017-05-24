# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package kdump_utils;
use base Exporter;
use Exporter;
use strict;
use testapi;
use utils;

our @EXPORT = qw(install_kernel_debuginfo prepare_for_kdump activate_kdump kdump_is_active do_kdump);

sub install_kernel_debuginfo {
    script_run 'zypper ref';
    zypper_call('-v in $(rpmquery kernel-default | sed "s/kernel-default/kernel-default-debuginfo/")');
}

sub prepare_for_kdump {
    # disable packagekitd
    pkcon_quit;
    zypper_call('in yast2-kdump kdump crash');

    # add debuginfo channels
    if (check_var('DISTRI', 'sle')) {
        # debuginfos for kernel has to be installed from build-specific directory on FTP.
        # To get the right directory we modify content of REPO_0 variable, e.g.:
        # SLE-12-SP2-Server-DVD-x86_64-Build2188-Media1 -> SLE-12-SP2-SERVER-POOL-x86_64-Build2188-Media3
        if (get_var('REPO_0')) {
            my $sles_debug_repo = get_var('REPO_0') =~ s/(Server|Desktop)/\U$1\E/r;
            $sles_debug_repo =~ s/DVD/POOL/;
            $sles_debug_repo =~ s/Media1/Media3/;
            my $url = "ftp://openqa.suse.de/$sles_debug_repo";
            zypper_call("ar -f $url SLES-Server-Debug");
            install_kernel_debuginfo;
            script_run 'zypper -n rr SLES-Server-Debug';
        }
        else {
            script_run(q{zypper mr -e $(zypper lr | awk '/Debug/ {print $1}')}, 60);
            install_kernel_debuginfo;
            script_run(q{zypper mr -d $(zypper lr | awk '/Debug/ {print $1}')}, 60);
        }
    }
    else {
        if (get_var('REPO_0_DEBUGINFO')) {
            my $snapshot_debuginfo_repo = get_var('REPO_0_DEBUGINFO');
            zypper_call('ar -f ' . get_var('MIRROR_HTTP') . "-debuginfo $snapshot_debuginfo_repo");
            install_kernel_debuginfo;
            script_run "zypper -n rr $snapshot_debuginfo_repo";
        }
        else {
            my $opensuse_debug_repos = 'repo-debug ';
            if (!check_var('VERSION', 'Tumbleweed')) {
                $opensuse_debug_repos .= 'repo-debug-update ';
            }
            zypper_call("mr -e $opensuse_debug_repos");
            install_kernel_debuginfo;
            zypper_call("mr -d $opensuse_debug_repos");
        }
    }
}

sub activate_kdump {
    # activate kdump
    script_run 'yast2 kdump', 0;
    my @tags = qw(yast2-kdump-disabled yast2-kdump-enabled yast2-kdump-restart-info yast2-missing_package yast2_console-finished);
    do {
        assert_screen \@tags, 300;
        # enable kdump if it is not already
        wait_screen_change { send_key 'alt-u' } if match_has_tag('yast2-kdump-disabled');
        wait_screen_change { send_key 'alt-o' } if match_has_tag('yast2-kdump-enabled');
        wait_screen_change { send_key 'alt-o' } if match_has_tag('yast2-kdump-restart-info');
        wait_screen_change { send_key 'alt-i' } if match_has_tag('yast2-missing_package');
    } until (match_has_tag('yast2_console-finished'));
}

sub kdump_is_active {
    # make sure kdump is enabled after reboot
    my $active = script_run("systemctl -q is-active kdump.service");
    record_soft_failure 'bsc#1022064' unless $active;
    return $active;
}

sub do_kdump {
    # get dump
    script_run "echo c > /proc/sysrq-trigger", 0;
}

1;

# vim: sw=4 et

