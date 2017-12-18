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
use List::Util qw(first);

our @EXPORT = qw(install_kernel_debuginfo prepare_for_kdump activate_kdump kdump_is_active do_kdump);

sub install_kernel_debuginfo {
    assert_script_run 'zypper ref', 300;
    my @kernels = split(/\n/, script_output('rpmquery --queryformat="%{NAME}-%{VERSION}-%{RELEASE}\n" kernel-default'));
    my ($uname) = script_output('uname -r') =~ /(\d+\.\d+\.\d+)-*/;
    my $debuginfo = first { $_ =~ /\Q$uname\E/ } @kernels;
    $debuginfo =~ s/default/default-debuginfo/g;
    zypper_call("-v in $debuginfo", timeout => 4000);
}


sub prepare_for_kdump_sle {
    my $sles_debug_repo;
    # debuginfos for kernel has to be installed from build-specific directory on FTP.
    if (get_var('REPO_SLES_DEBUG')) {
        my $url = "$utils::OPENQA_FTP_URL/" . get_var('REPO_SLES_DEBUG');
        zypper_call("ar -f $url SLES-Server-Debug");
        install_kernel_debuginfo;
        script_run 'zypper -n rr SLES-Server-Debug';
        return;
    }
    my $counter = 0;
    if (get_var('OS_TEST_ISSUES') && get_var('OS_TEST_TEMPLATE')) {
        # append _debug to the incident repo
        for my $b (split(/,/, get_var('OS_TEST_ISSUES'))) {
            next unless $b;
            $b = join($b, split('%INCIDENTNR%', get_var('OS_TEST_TEMPLATE')));
            $b =~ s,/$,_debug/,;
            $counter++;
            zypper_call("--no-gpg-check ar -f $b 'DEBUG_$counter'");
        }
    }
    script_run(q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}')), 60);
    install_kernel_debuginfo;
    script_run(q(zypper mr -d $(zypper lr | awk '/Debug/ {print $1}')), 60);
    for my $i (1 .. $counter) {
        script_run "zypper rr DEBUG_$i";
    }
}

sub prepare_for_kdump {
    # disable packagekitd
    pkcon_quit;
    zypper_call('in yast2-kdump kdump crash');

    # add debuginfo channels
    if (check_var('DISTRI', 'sle')) {
        prepare_for_kdump_sle;
        return;
    }

    if (get_var('REPO_0_DEBUGINFO')) {
        my $snapshot_debuginfo_repo = get_var('REPO_0_DEBUGINFO');
        zypper_call('ar -f ' . get_var('MIRROR_HTTP') . "-debuginfo $snapshot_debuginfo_repo");
        install_kernel_debuginfo;
        script_run "zypper -n rr $snapshot_debuginfo_repo";
        return;
    }
    my $opensuse_debug_repos = 'repo-debug ';
    if (!check_var('VERSION', 'Tumbleweed')) {
        $opensuse_debug_repos .= 'repo-debug-update ';
    }
    zypper_call("mr -e $opensuse_debug_repos");
    install_kernel_debuginfo;
    zypper_call("mr -d $opensuse_debug_repos");
}

sub activate_kdump {
    # activate kdump
    type_string 'echo "remove potential harmful nokogiri package boo#1047449"';
    zypper_call('rm -y ruby2.1-rubygem-nokogiri');
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

    my $status;
    for (1 .. 10) {
        $status = script_output('systemctl status kdump ||:');

        if ($status =~ /No kdump initial ramdisk found/) {
            record_soft_failure 'bsc#1021484 -- fail to create kdump initrd';
            assert_script_run 'systemctl restart kdump';
            $status = script_output('systemctl status kdump ||:');
            last;
        }
        elsif ($status =~ /Active: active/) {
            return 1;
        }
        elsif ($status =~ /Active: activating/) {
            diag "Service is activating, sleeping and looking again. Retry $_";
            sleep 10;
            next;
        }
        die "undefined state of kdump service";
    }
}

sub do_kdump {
    # get dump
    script_run "echo c > /proc/sysrq-trigger", 0;
}

1;

# vim: sw=4 et
