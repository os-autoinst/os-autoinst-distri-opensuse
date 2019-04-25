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
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_jeos);

our @EXPORT = qw(install_kernel_debuginfo prepare_for_kdump activate_kdump activate_kdump_without_yast kdump_is_active do_kdump);

sub install_kernel_debuginfo {
    assert_script_run 'zypper ref', 300;
    my $kernel    = is_jeos() ? 'kernel-default-base' : 'kernel-default';
    my $debuginfo = script_output('rpmquery --queryformat="%{NAME}-%{VERSION}-%{RELEASE}\n" ' . $kernel . '| sort --version-sort | tail -n 1');
    $debuginfo =~ s/$kernel/kernel-default-debuginfo/g;
    zypper_call("-v in $debuginfo", timeout => 4000);
}

sub get_repo_url_for_kdump_sle {
    return join('/', $utils::OPENQA_FTP_URL, get_var('REPO_SLE_MODULE_BASESYSTEM_DEBUG'))
      if get_var('REPO_SLE_MODULE_BASESYSTEM_DEBUG')
      and is_sle('15+');
    return join('/', $utils::OPENQA_FTP_URL, get_var('REPO_SLES_DEBUG')) if get_var('REPO_SLES_DEBUG');
}

sub prepare_for_kdump_sle {
    # debuginfos for kernel has to be installed from build-specific directory on FTP.
    my $url = get_repo_url_for_kdump_sle();
    if (defined $url) {
        zypper_call("ar -f $url SLES-Server-Debug");
        install_kernel_debuginfo;
        zypper_call('rr SLES-Server-Debug');
        return;
    }
    my $counter = 0;
    if (get_var('MAINT_TEST_REPO')) {
        # append _debug to the incident repo
        for my $b (split(/,/, get_var('MAINT_TEST_REPO'))) {
            next unless $b;
            $b =~ s,/$,_debug/,;
            $counter++;
            zypper_call("--no-gpg-check ar -f $b 'DEBUG_$counter'");
        }
    }
    script_run(q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}')), 60);
    install_kernel_debuginfo;
    script_run(q(zypper mr -d $(zypper lr | awk '/Debug/ {print $1}')), 60);
    for my $i (1 .. $counter) {
        zypper_call("rr DEBUG_$i");
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

    if (my $snapshot_debuginfo_repo = get_var('REPO_OSS_DEBUGINFO')) {
        zypper_call('ar -f ' . get_var('MIRROR_HTTP') . "-debuginfo $snapshot_debuginfo_repo");
        install_kernel_debuginfo;
        zypper_call("rr $snapshot_debuginfo_repo");
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
    type_string "echo \"remove potential harmful nokogiri package boo#1047449\"\n";
    zypper_call('rm -y ruby2.1-rubygem-nokogiri', exitcode => [0, 104]);
    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'kdump');
    my @tags        = qw(yast2-kdump-disabled yast2-kdump-enabled yast2-kdump-restart-info yast2-missing_package yast2_console-finished);
    do {
        assert_screen \@tags, 300;
        # for ppc64le and aarch64 we need increase kdump memory, see bsc#957053 and bsc#1120566
        if (check_var('ARCH', 'ppc64le') || check_var('ARCH', 'aarch64')) {
            if (check_screen 'current-kdmup-mem-size') {
                send_key 'alt-y';
                type_string '640';
                send_key 'ret';
                record_soft_failure 'default kdump memory size is too small, kdumptool gets killed by OOM, bsc#1120566';
            }
        }
        # enable kdump if it is not already
        wait_screen_change { send_key 'alt-u' } if match_has_tag('yast2-kdump-disabled');
        wait_screen_change { send_key 'alt-o' } if match_has_tag('yast2-kdump-enabled');
        wait_screen_change { send_key 'alt-o' } if match_has_tag('yast2-kdump-restart-info');
        wait_screen_change { send_key 'alt-i' } if match_has_tag('yast2-missing_package');
    } until (match_has_tag('yast2_console-finished'));
    wait_serial("$module_name-0", 240) || die "'yast2 kdump' didn't finish";
}

sub activate_kdump_without_yast {
    # activate kdump by grub, need a reboot to start kdump
    my $cmd = "";
    if (check_var('ARCH', 'ppc64le') || check_var('ARCH', 'aarch64')) {
        $cmd = "if [ -e /etc/default/grub ]; then sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/ s/\"\$/ crashkernel=256M \"/' /etc/default/grub; fi";
    }
    else {
        $cmd = "if [ -e /etc/default/grub ]; then sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/ s/\"\$/ crashkernel=256M,high crashkernel=128M,low \"/' /etc/default/grub; fi";
    }
    script_run($cmd);
    script_run('cat /etc/default/grub');
    # sync changes from /etc/default/grub into /boot/grub2/grub.cfg
    assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');
    systemctl('enable kdump.service');
}

sub kdump_is_active {
    # make sure kdump is enabled after reboot

    my $status;
    for (1 .. 10) {
        $status = script_output('systemctl status kdump ||:');

        if ($status =~ /No kdump initial ramdisk found/) {
            record_soft_failure 'bsc#1021484 -- fail to create kdump initrd';
            systemctl 'restart kdump';
            next;
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
