# SUSE's openQA tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

package kdump_utils;
use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use registration;
use Utils::Backends;
use Utils::Architectures;
use power_action_utils 'power_action';
use version_utils qw(is_sle is_jeos is_leap is_tumbleweed is_opensuse is_transactional
  is_leap_micro is_sle_micro);
use utils 'ensure_serialdev_permissions';
use virt_autotest::utils 'is_xen_host';

our @EXPORT = qw(install_kernel_debuginfo prepare_for_kdump
  activate_kdump activate_kdump_cli activate_kdump_without_yast activate_kdump_transactional
  kdump_is_active do_kdump configure_service check_function
  full_kdump_check deactivate_kdump_cli set_kdump_config);

sub determine_kernel_debuginfo_package {
    # Using the provided capabilities of the currently active kernel, get the
    # name and version of the shortest flavor and add "-debuginfo" to the name.
    return script_output('rpm -qf /boot/initrd-$(uname -r) --provides | awk \'match($0,/(kernel-.+)\(.+\) = (.+)/,m) {printf "%d %s-debuginfo-%s\n", length($0), m[1], m[2]}\' | sort -n | head -n1 | cut -d" " -f2-');
}

my $install_debug_info_timeout = 4000;

sub install_transactional_kernel_debuginfo {
    return undef if get_var('SKIP_KERNEL_DEBUGINFO');
    my $debuginfo = determine_kernel_debuginfo_package;
    my $cmd = "transactional-update --continue --non-interactive pkg install ${debuginfo}";
    assert_script_run($cmd, timeout => $install_debug_info_timeout);
}

sub install_kernel_debuginfo {
    return install_transactional_kernel_debuginfo if is_transactional;
    my $import_gpg = get_var('BUILD') =~ /^MR:/ ? '--gpg-auto-import-keys' : '';
    zypper_call "$import_gpg ref";
    return undef if get_var('SKIP_KERNEL_DEBUGINFO');
    my $debuginfo = determine_kernel_debuginfo_package;
    zypper_call("-v in $debuginfo", timeout => $install_debug_info_timeout);
}

sub get_repo_url_for_kdump_sle {
    my $openqa_url = 'http://' . get_var('OPENQA_HOSTNAME', 'openqa.suse.de') . '/assets/repo';
    return join('/', $openqa_url, get_var('REPO_SLE_MODULE_BASESYSTEM_DEBUG'))
      if get_var('REPO_SLE_MODULE_BASESYSTEM_DEBUG')
      and is_sle('15+');

    my $repo = is_sle('16+') ? 'REPO_SLES_16_DEBUG' : 'REPO_SLES_DEBUG';
    return join('/', $openqa_url, get_var("$repo")) if get_var("$repo");
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
    # use INCIDENT_REPO if defined, MR's contain also MAINT_TEST_REPO, but INCIDENT_REPO is relevant
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) if get_var('INCIDENT_REPO');
    if (get_var('MAINT_TEST_REPO')) {
        # append _debug to the incident repo
        for my $i (split(/,/, get_var('MAINT_TEST_REPO'))) {
            next unless $i;
            $i =~ s/\/$//;    # Delete / at the end of url
            $i =~ s/$/_debug/;
            $counter++;
            zypper_call("--no-gpg-checks ar -f $i 'DEBUG_$counter'");
        }
    }

    if (is_sle('=12-SP2')) {
        my $arch = get_var('ARCH');
        my $url = "http://dist.suse.de/ibs/SUSE/Updates/SLE-SERVER/12-SP2-LTSS-ERICSSON/$arch/update_debug/";
        zypper_call("--no-gpg-checks ar -f -G $url '12-SP2-LTSS-ERICSSON-Debuginfo-Updates'");
    }
    if (is_sle('=12-SP3')) {
        my $arch = get_var('ARCH');
        my $url = "http://dist.suse.de/ibs/SUSE/Updates/SLE-SERVER/12-SP3-LTSS-TERADATA/$arch/update_debug/";
        zypper_call("--no-gpg-checks ar -f -G $url '12-SP3-LTSS-TERADATA-Debuginfo-Updates'");
    }

    script_run(q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}')), 60);
    install_kernel_debuginfo;
    script_run(q(zypper mr -d $(zypper lr | awk '/Debug/ {print $1}')), 60);
    for my $i (1 .. $counter) {
        zypper_call("rr DEBUG_$i");
    }
}

sub install_kernel_debuginfo_via_repo {
    my ($repo_url) = @_;
    zypper_call("ar $repo_url debuginfo");
    install_kernel_debuginfo;
    zypper_call("rr debuginfo");
}

sub disable_packagekitd {
    return if is_transactional;
    quit_packagekit;
    my @pkgs = qw(kdump);
    push @pkgs, qw(yast2-kdump) if (is_opensuse || is_sle('<16'));
    push @pkgs, qw(crash);

    if (is_jeos && get_var('UEFI')) {
        push @pkgs, is_aarch64 ? qw(mokutil shim) : qw(mokutil);
    }
    zypper_call "in @pkgs";
}

sub prepare_for_kdump {
    my %args = @_;
    $args{test_type} //= '';

    disable_packagekitd;
    return if ($args{test_type} eq 'before');

    # add debuginfo channels
    if (check_var('DISTRI', 'sle')) {
        prepare_for_kdump_sle;
        return;
    }

    if (my $snapshot_debuginfo_repo = get_var('REPO_OSS_DEBUG')) {
        zypper_call('ar -f ' . get_var('MIRROR_PREFIX') . "/$snapshot_debuginfo_repo $snapshot_debuginfo_repo");
        install_kernel_debuginfo;
        zypper_call("rr $snapshot_debuginfo_repo");
        return;
    }

    # handle micro via REPO_TRANSACTIONAL_DEBUG or skip repo setup if not set
    if (my $transactional_debuginfo_repo = get_var('REPO_TRANSACTIONAL_DEBUG')) {
        return install_kernel_debuginfo_via_repo($transactional_debuginfo_repo);
    }
    return if is_leap_micro || is_sle_micro;

    my $opensuse_debug_repos = 'repo-debug';
    $opensuse_debug_repos .= ' repo-debug-update' unless is_tumbleweed;
    $opensuse_debug_repos .= ' repo-sle-debug-update' if is_leap("15.3+");
    zypper_call("mr -e $opensuse_debug_repos");
    install_kernel_debuginfo;
    zypper_call("mr -d $opensuse_debug_repos");
}

sub handle_warning_not_supported {
    my $warning = shift;

    if ($warning eq 'yast2-kdump-not-supported') {
        send_key 'ret';
        assert_screen 'yast2-kdump-cannot-read-mem';
        send_key 'ret';
    } elsif ($warning eq 'yast2-kdump-cannot-read-mem') {
        send_key 'ret';
    } else {
        die "Unknown warning message\n";
    }
}

sub handle_warning_install_os_prober {
    send_key('alt-i');
    wait_still_screen;
    wait_screen_change { send_key 'alt-n' };
}

# use yast2 kdump to enable the kdump service
sub activate_kdump {
    my (%args) = @_;
    # increase kdump memory when bsc#1161421 applies
    my $increase_kdump_memory = $args{increase_kdump_memory} // 1;
    # restart info will appear only when change has been done
    my $expect_restart_info = 0;

    # get kdump memory size bsc#1161421
    my $memory_total = script_output('kdumptool  calibrate | awk \'/Total:/ {print $2}\'');
    my $memory_kdump = $memory_total >= 2048 ? 1024 : 320;
    $memory_kdump = get_var('CRASH_MEMORY') if get_var('CRASH_MEMORY');
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'kdump', yast2_opts => '--ncurses');
    my @initial_tags = qw(yast2-kdump-disabled yast2-kdump-enabled);
    push(@initial_tags,
        (is_sle('>=15-sp3')) ? 'yast2-kdump-not-supported' : 'yast2-kdump-cannot-read-mem') if (is_xen_pv);

    assert_screen(\@initial_tags, 200);
    if (match_has_tag('yast2-kdump-not-supported') || match_has_tag('yast2-kdump-cannot-read-mem')) {
        handle_warning_not_supported(pop(@initial_tags));
        assert_screen(\@initial_tags, 200);
        send_key 'alt-c';
        wait_serial("$module_name-16") || die "'yast2 kdump' didn't finish";
        return 16;
    }
    if (match_has_tag('yast2-kdump-disabled')) {
        # enable kdump
        send_key('alt-u');
        assert_screen('yast2-kdump-enabled');
        $expect_restart_info = 1;
    }
    # ppcl64e and aarch64 needs increased kdump memory bsc#1161421
    # migration regression test cases need increase kdump memory since lot of services start
    if (is_ppc64le || is_aarch64 || get_var('FLAVOR') =~ /Regression/) {
        if ($increase_kdump_memory) {
            send_key('alt-y');
            type_string $memory_kdump;
            wait_screen_change(sub { send_key 'ret' }, 10) for (1 .. 2);
            record_soft_failure 'default kdump memory size is too small for ppc64le and aarch64, see bsc#1161421';
        }
        $expect_restart_info = 1;
    }
    # enable and verify fadump settings
    if (get_var('FADUMP') && check_screen('yast2-fadump-not-enabled')) {
        send_key 'alt-f';
        assert_screen 'yast2-fadump-enabled';
        $expect_restart_info = 1;
    }
    send_key('alt-o');
    # Expect yast2-kdump-restart-info on s390x
    $expect_restart_info = 1 if (is_s390x && is_sle('15-SP5+'));
    if ($expect_restart_info == 1) {
        my @tags = qw(yast2-kdump-restart-info os-prober-warning yast2-kdump-no-restart-info);
        do {
            assert_screen(\@tags, timeout => 180);
            handle_warning_install_os_prober() if match_has_tag('os-prober-warning');
        } until (match_has_tag('yast2-kdump-restart-info') || match_has_tag('yast2-kdump-no-restart-info'));
        send_key('alt-o') if match_has_tag('yast2-kdump-restart-info');
    }

    if (check_screen('yast2-kdump-restart-info', 180)) {
        record_info('bsc#1202629', 'yast2 kdump shows "To apply changes a reboot is necessary" even no changes there');
        send_key('alt-o');
    }

    wait_serial("$module_name-0", 240) || die "'yast2 kdump' didn't finish";
}

sub determine_crash_memory {
    # Use kdumptool calibrate to get default memory settings
    my $kdumptool_calibrate = script_output('kdumptool calibrate');
    record_info('KDUMPTOOL CALIBRATE', $kdumptool_calibrate);
    my $high_low = is_x86_64 ? 'High' : 'Low';
    my ($calibrated_memory) = $kdumptool_calibrate =~ /\s$high_low:[ ]*(\d*)/;

    # Set kernel crash memory from job variable or use kdumptool calibrate value
    my $crash_memory = get_var('CRASH_MEMORY') ? get_var('CRASH_MEMORY') : $calibrated_memory;
    record_info('CRASH MEMORY', $crash_memory);
    return $crash_memory;
}

# Activate kdump using command line tools
sub activate_kdump_cli {
    set_kdump_config('KDUMP_SAVEDIR', get_var('KDUMP_SAVEDIR')) if get_var('KDUMP_SAVEDIR');
    if (is_sle('16+')) {
        # Enable fadump in configuration file if requested
        set_kdump_config("KDUMP_FADUMP", "true") if get_var('FADUMP');

        # Set custom crashkernel if requested
        my $crash_memory = determine_crash_memory;
        set_kdump_config("KDUMP_CRASHKERNEL", "crashkernel=${crash_memory}M") if get_var('CRASH_MEMORY');

        # Apply configuration
        assert_script_run('kdumptool commandline -u');
        record_info('COMMANDLINE', script_output('kdumptool commandline'));
    }
    else {
        # Skip configuration, if is kdump already enabled and no special memory settings is required
        # and always proceed with kdump configuration if fadump is requested
        # Yast cli may timeout on with XEN bsc#1206274, we need to check configuration directly
        my $status;
        if (is_xen_host) {
            $status = script_run('! grep "GRUB_CMDLINE_XEN_DEFAULT.*crashkernel" /etc/default/grub');
        } else {
            $status = script_run('yast kdump show 2>&1 | grep "Kdump is disabled"', 180);
        }
        return if ($status and !get_var('CRASH_MEMORY') and !get_var('FADUMP'));

        # Make sure fadump is disabled on PowerVM
        assert_script_run('yast2 kdump fadump disable', 180) if is_pvm;

        my $crash_memory = determine_crash_memory;
        record_info('CRASH MEMORY', $crash_memory);
        assert_script_run("yast kdump startup enable alloc_mem=${crash_memory}", 180);
        # Enable firmware assisted dump if needed
        assert_script_run('yast2 kdump fadump enable', 180) if get_var('FADUMP');
        assert_script_run('yast kdump show', 180);
    }
    record_info('SYSCONFIG', script_output('cat /etc/sysconfig/kdump'));
    systemctl('enable kdump');
}

# Deactivate kdump using command line tools
sub deactivate_kdump_cli {
    if (is_sle('16+')) {
        assert_script_run('kdumptool commandline -d');
    } else {
        # Solution to poo113351. Avoid to use needles to solve this case.
        zypper_call("--gpg-auto-import-keys ref");
        # Disable the crashkernel option from the kernel grub cmdline
        assert_script_run('yast kdump startup disable alloc_mem=0', 180);
        # Disable the kdump service at boot time
    }
    systemctl('disable kdump');
}

sub activate_kdump_without_yast {
    # activate kdump by grub, need a reboot to start kdump
    my $cmd = "";
    if (is_ppc64le || is_aarch64) {
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

sub activate_kdump_transactional {
    if (get_var('CRASH_MEMORY')) {
        # show and get crashkernel memory
        my $crash_memory = determine_crash_memory;
        assert_script_run("transactional-update --continue setup-kdump --crashkernel=${crash_memory},0");
    } else {
        # show default craskernel memory
        determine_crash_memory;
        assert_script_run("transactional-update --continue setup-kdump");
    }
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
# we use $args{test_type} to distingush migration from function check.
#
# For migration test we just do activate kdump. migration test do
# not need to run prepare_for_kdump function because it can't get
# the debug media for the base system.
#
# For function test we need to install the debug kernel and activate kdump.
#
sub configure_service {
    my %args = @_;
    $args{test_type} //= '';
    $args{yast_interface} //= '';

    my $self = y2_module_consoletest->new();
    if ($args{test_type} eq 'function') {
        # preparation for crash test
        if ((is_sle '15+') && (is_sle '<16')) {
            add_suseconnect_product('sle-module-desktop-applications');
            add_suseconnect_product('sle-module-development-tools');
        }
    }

    prepare_for_kdump(%args);
    select_console 'root-console';
    if ($args{yast_interface} eq 'cli') {
        is_transactional ? activate_kdump_transactional : activate_kdump_cli;
    } else {
        return 16 if activate_kdump == 16;
    }

    # restart to activate kdump
    power_action('reboot', textmode => 1, keepconsole => is_pvm);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(bootloader_time => 300);

    select_console 'root-console';
    if (is_ppc64le || is_ppc64) {
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
    my %args = @_;
    $args{test_type} //= '';
    my $boot_timeout = is_aarch64 || is_hyperv ? 300 : undef;

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
    elsif (is_pvm || is_ipmi) {
        # Reconnect management console on pvm only after the crash, IPMI console is managed by wait_boot
        reconnect_mgmt_console if is_pvm;
    }
    else {
        power_action('reboot', textmode => 1, observe => 1, keepconsole => 1);
    }
    unlock_if_encrypted;
    # Wait for system's reboot; more time for Hyper-V / aarch64 as it's slow.
    $self->wait_boot(bootloader_time => $boot_timeout);
    select_console 'root-console';

    assert_script_run 'find /var/crash/';

    if ($args{test_type} eq 'function') {
        # check that core dump exists and that it is not empty
        assert_script_run('files=(/var/crash/*/vmcore) && test -s "${files[-1]}"', 240);

        # check the core dump via the crash utility if possible
        my $crash_cmd;
        my $vmcore_glob = '/var/crash/*/vmcore';
        my $vmlinux_glob = (is_sle("<16") || is_sle_micro("<6.0") || is_leap("<16.0"))
          ? '/boot/vmlinux-$(uname -r)*'
          : '/usr/lib/modules/$(uname -r)/vmlinux*';
        if (!is_transactional) {
            $crash_cmd = "echo exit | crash `ls -1t $vmcore_glob | head -n1` $vmlinux_glob";
        }
        elsif (!get_var('SKIP_KERNEL_DEBUGINFO')) {
            my $vmcore = script_output("ls -1t $vmcore_glob");
            my $vmlinux = script_output("ls -1t $vmlinux_glob");
            my $debuginfo = determine_kernel_debuginfo_package;
            my $vmlinuxd = script_output("rpm -ql ${debuginfo} | grep vmlinux");
            my $zypper_call = 'zypper -n in crash';
            my $crash_call = "echo exit | crash /host/$vmcore /host/$vmlinux /host/$vmlinuxd";
            my $bash_cmd = "$zypper_call && $crash_call";
            $crash_cmd = "podman container run --privileged -v '/:/host' registry.opensuse.org/opensuse/tumbleweed bash -c '$bash_cmd'";
        }
        validate_script_output $crash_cmd, sub { m/PANIC:\s([^\s]+)/ }, is_aarch64 ? 1200 : 800 if $crash_cmd;
    }
    else {
        # migration tests need remove core files before migration start
        assert_script_run 'rm -fr /var/crash/*';
    }

    # Test PoverVM specific scenario with disabled fadump on encrypted filesystem
    if (is_pvm && get_var('ENCRYPT') && get_var('FADUMP')) {
        # Disable fadump
        assert_script_run('yast2 kdump fadump disable', 180);
        assert_script_run('yast2 kdump show', 180);
        # Set print_delay to slow down kernel
        assert_script_run('echo 1000 > /proc/sys/kernel/printk_delay');
        # Restart system and check console
        power_action('reboot', keepconsole => 1);
        reconnect_mgmt_console;
        assert_screen('system-reboot', timeout => 180, no_wait => 1);
        $self->wait_boot(bootloader_time => 300);
        select_console 'root-console';
    }
}

# for bsc#1199326, we need to check if ~/bernhard/.ssh/id_rsa was not
# affected after kdump_and_crash.
sub check_ssh_files {
    # if file ~bernhard/.ssh/id_rsa missing or zero size
    # we need to recreate the ssh key.
    my $ret = script_run('! test -s ~bernhard/.ssh/id_rsa');
    if ($ret == 0) {
        record_soft_failure('bsc#1199326 - After kdump and crash the ssh configure files truns zero or gone');
        my $user = $testapi::username;
        assert_script_run("rm -f ~/.ssh/id_rsa");
        assert_script_run('ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa');
        assert_script_run("mkdir -pv ~/.ssh ~$user/.ssh");
        assert_script_run("cp ~/.ssh/id_rsa ~$user/.ssh/id_rsa");
        assert_script_run("touch ~{,$user}/.ssh/{authorized_keys,known_hosts}");
        assert_script_run("chmod 600 ~{,$user}/.ssh/*");
        assert_script_run("chown -R bernhard ~$user/.ssh");
        assert_script_run("cat ~/.ssh/id_rsa.pub | tee -a ~{,$user}/.ssh/authorized_keys");
        assert_script_run("ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~{,$user}/.ssh/known_hosts");
    }
}

#
# Check kdump service before and after migration,
# parameter $stage is 'before' or 'after' of a system migration stage.
#
sub full_kdump_check {
    my (%hash) = @_;
    my $stage = $hash{stage};

    select_console 'root-console';

    if ($stage eq 'before') {
        configure_service(test_type => $stage, yast_interface => 'cli');
    }
    check_function();

    if ($stage ne 'before') {
        ensure_serialdev_permissions;
    }
    # We need to check bsc#1199326 after kdump_and_crash
    if ($stage eq 'after') {
        check_ssh_files();
    }
}

=head2 set_kdump_config

 set_kdump_config($option, $value);

This function modifies a configuration option within the F</etc/sysconfig/kdump> file.

=over 4

=item B<$option>

Name of the configuration option in the kdump configuration file.

=item B<$value>

Value for the configuration option.

=back

=cut

sub set_kdump_config {
    my ($option, $value) = @_;
    my $escaped_value = quotemeta($value);

    record_info("SET CONFIG", "$option=\"$value\"");
    my $command = "sed -i 's/^$option=.*/$option=\"$escaped_value\"/' /etc/sysconfig/kdump";

    assert_script_run($command);
}

1;
