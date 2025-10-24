# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Add the rust-keylime package (attestation)
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#177339

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl);

sub run {
    select_serial_terminal;

    # Install rust-keylime package (replacing legacy Python packages)
    zypper_call('in rust-keylime');

    # Record the rust-keylime version for reference
    my $pkg_version = script_output("rpm -q --qf '%{version}' rust-keylime");
    record_info("rust-keylime version", "Current rust-keylime version:\n $pkg_version");

    # Copy the rust-keylime configuration files
    my $agent_cfg_path = '/etc/keylime/agent.conf.d/agent.conf';
    assert_script_run('mkdir -p /etc/keylime/agent.conf.d');
    assert_script_run("cp -n /usr/etc/keylime/agent.conf $agent_cfg_path");
    assert_script_run('chown -R keylime:tss /etc/keylime');
    assert_script_run('chmod -R 600 /etc/keylime');

    # As test purpose, we will start keylime agent on single node
    # Setting the `receive_revocation_ip` and `registrar_ip` to 127.0.0.1 in the agent's config
    assert_script_run qq(sed -i 's/^registrar_ip = "<REMOTE_IP>"/registrar_ip = "127.0.0.1"/' $agent_cfg_path);
    assert_script_run qq(sed -i 's/^receive_revocation_ip = "<REMOTE_IP>"/receive_revocation_ip = "127.0.0.1"/' $agent_cfg_path);

    # Start and check the rust-keylime agent service
    systemctl('restart keylime_agent.service');
    systemctl('is-active keylime_agent.service');
}

1;
