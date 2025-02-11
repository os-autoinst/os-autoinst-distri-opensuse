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
use version_utils qw(is_transactional is_sle is_sle_micro is_tumbleweed);
use transactional qw(trup_call check_reboot_changes);
use serial_terminal qw(select_user_serial_terminal select_serial_terminal);
use registration qw(add_suseconnect_product get_addon_fullname);
use Utils::Architectures 'is_aarch64';
use Utils::Logging 'save_and_upload_log';

our @EXPORT = qw(install_bats install_ncat remove_mounts_conf switch_to_user delegate_controllers enable_modules patch_logfile bats_post_hook);

sub install_ncat {
    return if (script_run("rpm -q ncat") == 0);

    my $version = "SLE_15";
    if (is_sle_micro('<6.0')) {
        if (is_sle_micro('=5.5')) {
            $version = "SLE_15_SP5";
        } elsif (is_sle_micro('>5.2')) {
            $version = "SLE_15_SP4";
        } else {
            $version = "SLE_15_SP3";
        }
    } elsif (is_sle('<15-SP6')) {
        $version = get_required_var("VERSION");
        $version =~ s/-/_/g;
        $version = "SLE_" . $version;
    } elsif (is_tumbleweed) {
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
        if (is_transactional) {
            trup_call "--continue run $cmd";
        } else {
            assert_script_run "$cmd";
        }
    }
}

sub install_bats {
    return if (script_run("which bats") == 0);

    my $bats_version = get_var("BATS_VERSION", "1.11.0");

    script_retry("curl -sL https://github.com/bats-core/bats-core/archive/refs/tags/v$bats_version.tar.gz | tar -zxf -", retry => 5, delay => 60, timeout => 300);
    assert_script_run "bash bats-core-$bats_version/install.sh /usr/local";
    assert_script_run "rm -rf bats-core-$bats_version";

    script_run "mkdir -m 0750 /etc/sudoers.d/";
    assert_script_run "echo 'Defaults secure_path=\"/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin\"' > /etc/sudoers.d/usrlocal";

    assert_script_run "curl -o /usr/local/bin/bats_skip_notok " . data_url("containers/bats_skip_notok.py");
    assert_script_run "chmod +x /usr/local/bin/bats_skip_notok";
}

sub remove_mounts_conf {
    if (script_run("test -f /etc/containers/mounts.conf -o -f /usr/share/containers/mounts.conf") == 0) {
        if (is_transactional) {
            trup_call "run rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";
            check_reboot_changes;
        } else {
            script_run "rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";
        }
    }
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

    if (is_transactional) {
        select_console "user-console";
    } else {
        select_user_serial_terminal();
    }
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
    add_suseconnect_product(get_addon_fullname('desktop'));
    add_suseconnect_product(get_addon_fullname('sdk'));
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle('>=15-SP4');
    # Needed for libcriu2
    add_suseconnect_product(get_addon_fullname('phub'));
}

sub patch_logfile {
    my ($log_file, @skip_tests) = @_;

    foreach my $test (@skip_tests) {
        next if ($test eq "none");
        if (script_run("grep -q 'in test file.*/$test.bats' $log_file") != 0) {
            record_info("BATS: Test $test passed!");
        }
    }
    assert_script_run "bats_skip_notok $log_file " . join(' ', @skip_tests) if (@skip_tests);
}

sub bats_post_hook {
    select_serial_terminal;
    save_and_upload_log('dmesg', 'dmesg.txt');
    save_and_upload_log('rpm -qa | sort', 'rpm-qa.txt');
    save_and_upload_log('journalctl', 'journalctl.txt');
    upload_logs('/var/log/audit/audit.log', log_name => "audit.txt");
}
