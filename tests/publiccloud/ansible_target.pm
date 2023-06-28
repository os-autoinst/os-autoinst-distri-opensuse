# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: prepare the VM to grant access to ansible_client
# Maintainer: qa-c@suse.de

use base "consoletest";
use serial_terminal 'select_serial_terminal';
use transactional qw(trup_call process_reboot);
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network qw(setup_static_mm_network);
use utils qw(zypper_call);
use Utils::Systemd qw(systemctl);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    record_info('system', script_output('cat /etc/os-release'));
    record_info('device', script_output('nmcli -t device'));

    setup_static_mm_network('10.0.2.20/15');

    record_info('ip', script_output('ip a'));
    record_info('route', script_output('ip r'));
    script_run('ping -c 1 10.0.2.15');
    script_run('ping -c 1 download.suse.de');

    assert_script_run('curl -f -v ' . autoinst_url . '/data/slenkins/ssh/authorized_keys >> /root/.ssh/authorized_keys');
    assert_script_run('curl -f -v ' . autoinst_url . '/data/publiccloud/pcw/sshd_config >/etc/ssh/sshd_config');

    zypper_call('--gpg-auto-import-keys ref');
    trup_call('pkg install python3 python3-selinux');
    process_reboot(trigger => 1);

    systemctl('restart sshd');
    systemctl('status sshd');
    mutex_create 'target_is_ready';

    assert_script_run('ping -c 1 10.0.2.15');
    mutex_wait 'job_completed';
}

1;
