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
use version_utils qw(is_openstack is_public_cloud is_opensuse);

my @errors = ();

sub run {
    my ($self, $args) = @_;
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
    record_info('VERSION', script_output('cloud-init -v'));
    record_info('STATUS', script_output('cloud-init status --wait --long', proceed_on_failure => 1));
    record_info('ANALYZE', script_output('cloud-init analyze show'));
    record_info('DUMP', script_output('cloud-init analyze dump'));
    record_info('BLAME', script_output('cloud-init analyze blame'));
    record_info('BOOT', script_output('cloud-init analyze boot', proceed_on_failure => 1));
    record_info('SCHEMA', script_output('cloud-init schema --system', proceed_on_failure => 1));

    # Registration
    unless (is_opensuse || get_var('NO_CLOUD')) {
        if (script_run('test -f /etc/zypp/credentials.d/SCCcredentials')) {
            push @errors, 'System was not registered';
        }
        assert_script_run('SUSEConnect --status-text', timeout => 120);
    }

    # just_a_test.service should be enabled and executed
    systemctl('is-enabled just_a_test.service');
    assert_script_run('journalctl --no-pager -u just_a_test.service |grep "Test service has started"');
    systemctl('disable just_a_test.service');

    # Package installation
    unless (get_var('NO_CLOUD')) {
        assert_script_run('rpm -q lshw');
        assert_script_run('lshw -short');
    }

    # Hostname and timezone
    assert_script_run('hostnamectl hostname | grep cucaracha');
    assert_script_run('timedatectl status | grep Europe/Prague');

    # User checks
    # Applicable for cloud environments as the keys are pushed from cloud client tools
    if (is_openstack || is_public_cloud) {
        assert_script_run('ls -la ~/.ssh/');
        if (script_run('test -s ~/.ssh/authorized_keys')) {
            push @errors, "No pubkeys added to root";
        }
    }
    # system should use /usr/etc/sudoers
    # cloud init should not create an empty /etc/sudeoers
    # sudo commands will fail as secure_path will be missing
    if (script_run('test -f /etc/sudoers') == 0) {
        script_run('rpm -V $(rpm -qf /etc/sudoers)');
        if (script_run('rpm -qf /etc/sudoers')) {
            push @errors, "cloud-init has created sudoers configuration hence the system default will be overriden";
        }
    }

    foreach my $u (keys %{$users}) {
        my $policy = (split(' ', script_output("passwd --status $u")))[1];
        if ($policy !~ /\b$users->{$u}->{passwd}\b/) {
            push @errors, "$u has wrong password policy, detected $policy and expected $users->{$u}";
        }
    }

    # check whether the rootfs was expanded properly
    my $partition = script_output 'findmnt -nrvo SOURCE /';
    ##TODO: bug????
    script_output "sfdisk --list-free $partition";

    # before logging bernhard, set serialdev permissions for both test users
    ensure_serialdev_permissions();
    {
        local $testapi::username = 'tester_ssh';
        ensure_serialdev_permissions();
    }

    select_console('user-console');
    assert_script_run('sudo sysctl -a');
    enter_cmd('sudo -u tester_ssh -i');
    assert_script_run('cat ~/.ssh/authorized_keys | grep rsa');
    assert_script_run('cat ~/.ssh/authorized_keys | grep ecdsa');
    assert_script_run('sudo sysctl -a');
    enter_cmd('exit');

    if (is_openstack || is_public_cloud) {
        select_host_console(force => 1);
        foreach my $u (keys %{$users}) {
            $args->{my_instance}->ssh_assert_script_run(cmd => "who -u | grep $u",
                username => $u,
                ssh_opts => "-i $users->{$u}->{keyid}"
            );
        }
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

sub post_run_hook {
    return if (is_openstack || is_public_cloud);

    select_console('root-console');
    upload_logs("/var/log/cloud-init.log");
    upload_logs("/var/log/cloud-init-output.log");
    upload_logs('/etc/cloud/cloud.cfg');
    save_and_upload_log('tar cJvf run_ci_files.tar.xz /run/cloud-init/', 'run_ci_files.tar.xz');
}

sub post_fail_hook {
    if (@errors) {
        record_info('Errors', join('\n', @errors), result => 'fail');
    }

    return if (is_openstack || is_public_cloud);
    select_console('root-console');

    upload_logs("/var/log/cloud-init.log");
    upload_logs("/var/log/cloud-init-output.log");
    upload_logs('/etc/cloud/cloud.cfg');
    save_and_upload_log('tar cJvf run_ci_files.tar.xz /run/cloud-init/', 'run_ci_files.tar.xz');
    save_and_upload_log('journalctl --no-pager', 'journal.txt');
    save_and_upload_log('dmesg -x', 'dmesg.txt');
}

1;
