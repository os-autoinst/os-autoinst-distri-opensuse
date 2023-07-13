# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check cloud-init configuration of the image
# Maintainer: QA-c <qa-c@suse.com>

use Mojo::Base qw(publiccloud::basetest);
use testapi;
use Utils::Systemd qw(systemctl);
use Utils::Logging qw(save_and_upload_log);
use publiccloud::ssh_interactive qw(select_host_console);
use utils qw(ensure_serialdev_permissions);

sub run {
    my ($self, $args) = @_;
    my @errors = ();
    my $users = {
        tester_ssh => {
            passwd => 'L',
            keyid => '~/.ssh/test_ci_ecdsa'
        },
        $testapi::username => {
            passwd => 'P',
            keyid => '~/.ssh/id_rsa'
        }
    };

    select_console('root-console');
    assert_script_run('cloud-init status --wait --long');

    # Registration
    if (script_run('test -f /etc/zypp/credentials.d/SCCcredentials')) {
        push @errors, 'System was not registered';
    }
    assert_script_run('SUSEConnect --status-text | grep -i active', timeout => 120);

    # qemu-guest-agent service should be enabled and started
    assert_script_run('rpm -q qemu-guest-agent');
    systemctl('is-enabled qemu-guest-agent');
    if (script_run('systemctl --no-pager is-active qemu-guest-agent')) {
        record_soft_failure("bsc#1207135 - [Build 2.56] qemu-guest-agent.service: Job qemu-guest-agent.service/start failed with result 'dependency'");
    }

    # Package installation
    assert_script_run('rpm -q iotop');
    assert_script_run('iotop -b -n 1');

    # Hostname and timezone
    assert_script_run('hostnamectl hostname | grep cucaracha');
    assert_script_run('timedatectl status | grep Europe/Prague');

    # User checks
    assert_script_run('ls -la ~/.ssh/');
    assert_script_run('test -s ~/.ssh/authorized_keys');
    foreach my $u (keys %{$users}) {
        my $policy = (split(' ', script_output("passwd --status $u")))[1];
        if ($policy !~ /\b$users->{$u}->{passwd}\b/) {
            push @errors, "$u has wrong password policy, detected $policy and expected $users->{$u}";
        }
    }

    select_console('user-console');
    assert_script_run('sudo sysctl -a');
    enter_cmd('sudo -u tester_ssh -i');
    assert_script_run('cat ~/.ssh/authorized_keys | grep rsa');
    assert_script_run('cat ~/.ssh/authorized_keys | grep ecdsa');
    assert_script_run('sudo sysctl -a');
    enter_cmd('exit');

    select_host_console(force => 1);
    foreach my $u (keys %{$users}) {
        $args->{my_instance}->ssh_assert_script_run(cmd => "who -u | grep $u",
            username => $u,
            ssh_opts => "-i $users->{$u}->{keyid}"
        );
    }

    if (@errors) {
        die join('\n', @errors);
    }
}

sub test_flags {
    return {
        fatal => 0,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

sub post_fail_hook {
    select_console('log-console');

    upload_logs("/var/log/cloud-init.log");
    upload_logs("/var/log/cloud-init-output.log");
    save_and_upload_log('journalctl --no-pager', 'journal.txt');
    save_and_upload_log('dmesg -x', 'dmesg.txt');
}

1;
