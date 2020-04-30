# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package kdump_utils;
use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use registration;
use Utils::Backends 'is_pvm';
use Utils::Architectures qw(is_ppc64le is_aarch64);
use power_action_utils 'power_action';
use version_utils qw(is_sle is_jeos is_leap is_tumbleweed is_opensuse);
use utils 'ensure_serialdev_permissions';


our @EXPORT = qw(install_kernel_debuginfo prepare_for_kdump
  activate_kdump activate_kdump_without_yast kdump_is_active
  do_kdump configure_service check_function full_kdump_check);

sub install_kernel_debuginfo {
    zypper_call 'ref';
    my $kernel    = script_output('rpm -qf --qf %{name} /boot/initrd-$(uname -r)');
    my $debuginfo = script_output('rpmquery --queryformat="%{NAME}-%{VERSION}-%{RELEASE}\n" ' . $kernel . '| sort --version-sort | tail -n 1');
    $debuginfo =~ s/$kernel/$kernel-debuginfo/g;
    # Since SLE15-SP2+/Leap 15.2+ (standard and JeOS) there is 'kernel-default-base' but no 'kernel-default-base-debuginfo'
    # use 'kernel-default-debuginfo' instead.
    if ((is_sle('>=15-sp2') || is_leap('>=15.2') || is_tumbleweed) && $kernel eq 'kernel-default-base') {
        $debuginfo =~ s/-base//g;
        # kernel-default-base repackages kernel-default as an independent package now. They both work with kernel-default-debuginfo package.
        # kernel-default-base has extra numbers added to the release version. e.g.
        # - kernel-default           5.3.7-1.2
        # - kernel-default-base      5.3.7-1.2.7.14
        # - kernel-default-debuginfo 5.3.7-1.2
        # Ignore the extra numbers added to the release version.
        $debuginfo =~ s/(.*?)(\.lp\d+)*(\.\d+){2}$/$1/;
    }
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
        for my $i (split(/,/, get_var('MAINT_TEST_REPO'))) {
            next unless $i;
            $i =~ s,/$,_debug/,;
            $counter++;
            zypper_call("--no-gpg-checks ar -f $i 'DEBUG_$counter'");
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
    my ($test_type) = @_;
    $test_type //= '';

    # disable packagekitd
    pkcon_quit;
    if ($test_type eq 'before') {
        zypper_call('in yast2-kdump kdump');
    }
    else {
        zypper_call('in yast2-kdump kdump crash');
    }
    zypper_call('in mokutil') if is_jeos && get_var('UEFI');

    return if ($test_type eq 'before');

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

# use yast2 kdump to enable the kdump service
sub activate_kdump {
    # restart info will appear only when change has been done
    my $expect_restart_info = 0;
    # get kdump memory size bsc#1161421
    my $memory_total = script_output('kdumptool  calibrate | awk \'/Total:/ {print $2}\'');
    my $memory_kdump = $memory_total >= 2048 ? 1024 : 320;
    my $module_name  = y2_module_consoletest::yast2_console_exec(yast2_module => 'kdump', yast2_opts => '--ncurses');
    assert_screen([qw(yast2-kdump-disabled yast2-kdump-enabled)], 200);
    if (match_has_tag('yast2-kdump-disabled')) {
        # enable kdump
        send_key('alt-u');
        assert_screen('yast2-kdump-enabled');
        $expect_restart_info = 1;
    }
    # ppcl64e and aarch64 needs increased kdump memory bsc#1161421
    if (is_ppc64le || is_aarch64) {
        send_key('alt-y');
        type_string $memory_kdump;
        send_key('ret');
        record_soft_failure 'default kdump memory size is too small for ppc64le and aarch64, see bsc#1161421';
        $expect_restart_info = 1;
    }
    # enable and verify fadump settings
    if (get_var('FADUMP') && check_screen('yast2-fadump-not-enabled')) {
        send_key 'alt-f';
        assert_screen 'yast2-fadump-enabled';
        $expect_restart_info = 1;
    }
    send_key('alt-o');
    if ($expect_restart_info == 1) {
        assert_screen('yast2-kdump-restart-info', 200);
        send_key('alt-o');
    }
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

#
# Install debug kernel and use yast2 kdump to enable kdump service.
# we use $test_type to distingush  migration or function check.
#
# For migration test we just do activate kdump. migration test do
# not need to run prepare_for_kdump function because it can't get
# the debug media for the base system.
#
# For function test we need to install the debug kernel and activate kdump.
#
sub configure_service {
    my ($test_type) = @_;
    $test_type //= '';

    my $self = y2_module_consoletest->new();
    if ($test_type eq 'function') {
        # preparation for crash test
        if (is_sle '15+') {
            add_suseconnect_product('sle-module-desktop-applications');
            add_suseconnect_product('sle-module-development-tools');
        }
    }

    prepare_for_kdump($test_type);
    activate_kdump;

    # restart to activate kdump
    power_action('reboot', keepconsole => is_pvm);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(bootloader_time => 300);

    select_console 'root-console';
    if (check_var('ARCH', 'ppc64le') || check_var('ARCH', 'ppc64')) {
        if (script_run('kver=$(uname -r); kconfig="/boot/config-$kver"; [ -f $kconfig ] && grep ^CONFIG_RELOCATABLE $kconfig')) {
            record_soft_failure 'poo#49466 -- No kdump if no CONFIG_RELOCATABLE in kernel config';
            return 1;
        }
    }
}

#
# Trigger kernel dump and check the core files.
#
# For migration we just simply check the system memory can be dumped
# and core files are existed after reboot.
#
# For function test we need check the system memory can be dumped
# and can be debugged by crash.
#
sub check_function {
    my ($test_type) = @_;
    $test_type //= '';

    my $self = y2_module_consoletest->new();

    # often kdump could not be enabled: bsc#1022064
    return 1 unless kdump_is_active;

    do_kdump;

    if (get_var('FADUMP')) {
        reconnect_mgmt_console;
        unlock_if_encrypted;
        assert_screen 'grub2', 180;
        wait_screen_change { send_key 'ret' };
    }
    elsif (is_pvm) {
        reconnect_mgmt_console;
    }
    else {
        power_action('reboot', observe => 1, keepconsole => 1);
    }
    unlock_if_encrypted;
    # Wait for system's reboot; more time for Hyper-V as it's slow.
    $self->wait_boot(bootloader_time => check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 200 : undef);
    select_console 'root-console';

    assert_script_run 'find /var/crash/';

    if ($test_type eq 'function') {
        my $crash_cmd = "echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`*";
        validate_script_output "$crash_cmd", sub { m/PANIC:\s([^\s]+)/ }, 600;
    }
    else {
        # migration tests need remove core files before migration start
        assert_script_run 'rm -fr /var/crash/*';
    }

    # Test PoverVM specific scenario with disabled fadump on encrypted filesystem
    if (is_pvm && get_var('ENCRYPT') && get_var('FADUMP')) {
        # Disable fadump
        assert_script_run('yast2 kdump fadump disable', 120);
        assert_script_run('yast2 kdump show',           120);
        # Set print_delay to slow down kernel
        assert_script_run('echo 1000 > /proc/sys/kernel/printk_delay');
        # Restart system and check console
        power_action('reboot', keepconsole => 1);
        reconnect_mgmt_console;
        assert_screen('system-reboot', timeout => 120, no_wait => 1);
        $self->wait_boot(bootloader_time => 300);
        select_console 'root-console';
    }
}

#
# Check kdump service before and after migration,
# parameter $stage is 'before' or 'after' of a system migration stage.
#
sub full_kdump_check {
    my ($stage) = @_;
    $stage //= '';

    select_console 'root-console';

    if ($stage eq 'before') {
        configure_service('before');
    }
    check_function();

    if ($stage ne 'before') {
        ensure_serialdev_permissions;
    }
}

1;
