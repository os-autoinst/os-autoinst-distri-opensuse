# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Common functions for BATS test suites
# Maintainer: qa-c@suse.de

package containers::bats;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils qw(is_sle is_tumbleweed);
use serial_terminal qw(select_user_serial_terminal select_serial_terminal);
use registration qw(add_suseconnect_product get_addon_fullname);
use Utils::Architectures 'is_aarch64';
use Utils::Logging 'save_and_upload_log';
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils 'power_action';
use List::MoreUtils qw(uniq);
use containers::common qw(install_packages);

our @EXPORT = qw(
  bats_post_hook
  bats_setup
  enable_modules
  install_bats
  install_ncat
  install_oci_runtime
  patch_logfile
  selinux_hack
  switch_to_user
);

sub install_ncat {
    return if (script_run("rpm -q ncat") == 0);

    my $version = "SLE_15";
    if (is_sle('<15-SP6')) {
        $version = get_required_var("VERSION");
        $version =~ s/-/_/g;
        $version = "SLE_" . $version;
    } elsif (is_tumbleweed || is_sle('>=16')) {
        $version = "openSUSE_Factory";
        $version .= "_ARM" if (is_aarch64);
    }

    my $repo = "https://download.opensuse.org/repositories/network:/utilities/$version/network:utilities.repo";

    my @cmds = (
        "zypper addrepo $repo",
        "zypper --gpg-auto-import-keys -n install ncat",
        "ln -sf /usr/bin/ncat /usr/bin/nc"
    );
    foreach my $cmd (@cmds) {
        assert_script_run "$cmd";
    }
}

sub install_bats {
    return if (script_run("which bats") == 0);

    my $bats_version = get_var("BATS_VERSION", "1.11.1");

    script_retry("curl -sL https://github.com/bats-core/bats-core/archive/refs/tags/v$bats_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "bash bats-core-$bats_version/install.sh /usr/local";
    assert_script_run "rm -rf bats-core-$bats_version";

    script_run "mkdir -m 0750 /etc/sudoers.d/";
    assert_script_run "echo 'Defaults secure_path=\"/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin\"' > /etc/sudoers.d/usrlocal";
    assert_script_run "echo '$testapi::username ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd";

    assert_script_run "curl -o /usr/local/bin/bats_skip_notok " . data_url("containers/bats_skip_notok.py");
    assert_script_run "chmod +x /usr/local/bin/bats_skip_notok";
}

sub install_oci_runtime {
    my $oci_runtime = get_var("OCI_RUNTIME", script_output("podman info --format '{{ .Host.OCIRuntime.Name }}'"));
    install_packages($oci_runtime);
    script_run "mkdir /etc/containers/containers.conf.d";
    assert_script_run "echo -e '[engine]\nruntime=\"$oci_runtime\"' >> /etc/containers/containers.conf.d/engine.conf";
    record_info("OCI runtime", $oci_runtime);
    return $oci_runtime;
}

sub get_user_subuid {
    my ($user) = shift;
    my $start_range = script_output("awk -F':' '\$1 == \"$user\" {print \$2}' /etc/subuid", proceed_on_failure => 1);
    return $start_range;
}

sub switch_to_user {
    my $user = $testapi::username;

    if (script_run("grep $user /etc/passwd") != 0) {
        my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
        assert_script_run "useradd -m -G $serial_group $user";
        assert_script_run "echo '${user}:$testapi::password' | chpasswd";
        ensure_serialdev_permissions;
    }

    my $subuid_start = get_user_subuid($user);
    if ($subuid_start eq '') {
        # bsc#1185342 - YaST does not set up subuids/-gids for users
        $subuid_start = 200000;
        my $subuid_range = $subuid_start + 65535;
        assert_script_run "usermod --add-subuids $subuid_start-$subuid_range --add-subgids $subuid_start-$subuid_range $user";
    }
    assert_script_run "grep $user /etc/subuid", fail_message => "subuid range not assigned for $user";
    assert_script_run "setfacl -m u:$user:r /etc/zypp/credentials.d/*" if is_sle;

    select_user_serial_terminal();
}

sub delegate_controllers {
    if (script_run("test -f /etc/systemd/system/user@.service.d/60-delegate.conf") != 0) {
        # Let user control cpu, io & memory control groups
        # https://susedoc.github.io/doc-sle/main/html/SLES-tuning/cha-tuning-cgroups.html#sec-cgroups-user-sessions
        script_run "mkdir /etc/systemd/system/user@.service.d/";
        assert_script_run 'echo -e "[Service]\nDelegate=cpu cpuset io memory pids" > /etc/systemd/system/user@.service.d/60-delegate.conf';
        systemctl "daemon-reload";
    }
}

sub enable_modules {
    return if is_sle("16+");    # no modules on SLES16+

    add_suseconnect_product(get_addon_fullname('desktop'));
    add_suseconnect_product(get_addon_fullname('sdk'));
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle('>=15-SP4');
    # Needed for libcriu2
    add_suseconnect_product(get_addon_fullname('phub'));
}

sub patch_logfile {
    my ($log_file, @skip_tests) = @_;

    @skip_tests = uniq sort @skip_tests;

    foreach my $test (@skip_tests) {
        next if ($test eq "none");
        if (script_run("grep -q 'in test file.*/$test.bats' $log_file") != 0) {
            record_info("BATS: Test $test passed!");
        }
    }
    assert_script_run "bats_skip_notok $log_file " . join(' ', @skip_tests) if (@skip_tests);
}

sub fix_tmp {
    my $override_conf = <<'EOF';
[Unit]
ConditionPathExists=/var/tmp

[Mount]
What=/var/tmp
Where=/tmp
Type=none
Options=bind
EOF

    assert_script_run "mkdir /etc/systemd/system/tmp.mount.d/";
    assert_script_run "echo '$override_conf' > /etc/systemd/system/tmp.mount.d/override.conf";
}

sub bats_setup {
    my $self = shift;
    my $reboot_needed = 0;

    delegate_controllers;

    if (check_var("ENABLE_SELINUX", "0") && script_output("getenforce") eq "Enforcing") {
        record_info("Disabling SELinux");
        assert_script_run "sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config";
        assert_script_run "setenforce 0";
    }

    # Remove mounts.conf
    script_run "rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";

    # Disable tmpfs from next boot
    if (script_output("findmnt -no FSTYPE /tmp", proceed_on_failure => 1) =~ /tmpfs/) {
        # Bind mount /tmp to /var/tmp
        fix_tmp;
        $reboot_needed = 1;
    }

    # Switch to cgroup v2 if not already active
    if (script_run("test -f /sys/fs/cgroup/cgroup.controllers") != 0) {
        add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=1", update_grub => 1);
        $reboot_needed = 1;
    }

    if ($reboot_needed) {
        power_action('reboot', textmode => 1);
        $self->wait_boot();
    }

    select_serial_terminal;

    assert_script_run "mount --make-rshared /tmp" if (script_run("findmnt -no FSTYPE /tmp") == 0);
}

sub selinux_hack {
    my $dir = shift;

    # Use the same labeling in /var/lib/containers for $dir
    # https://github.com/containers/podman/blob/main/troubleshooting.md#11-changing-the-location-of-the-graphroot-leads-to-permission-denied
    script_run "sudo semanage fcontext -a -e /var/lib/containers $dir", timeout => 120;
    script_run "sudo restorecon -R -v $dir";
}

sub bats_post_hook {
    my $test_dir = shift;

    select_serial_terminal;

    my $log_dir = "/tmp/logs/";
    assert_script_run "mkdir -p $log_dir";
    assert_script_run "cd $log_dir";

    script_run "rm -rf $test_dir";

    script_run('df -h > df-h.txt');
    script_run('dmesg > dmesg.txt');
    script_run('findmnt > findmnt.txt');
    script_run('rpm -qa | sort > rpm-qa.txt');
    script_run('systemctl > systemctl.txt');
    script_run('systemctl status > systemctl-status.txt');
    script_run('systemctl list-unit-files > systemctl_units.txt');
    script_run('journalctl -b > journalctl-b.txt', timeout => 120);
    script_run('tar zcf containers-conf.tgz $(find /etc/containers /usr/share/containers -type f)');

    my @logs = split /\s+/, script_output "ls";
    for my $log (@logs) {
        upload_logs($log_dir . $log);
    }

    upload_logs('/var/log/audit/audit.log', log_name => "audit.txt");
}
