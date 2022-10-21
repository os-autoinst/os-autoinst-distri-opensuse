# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Add the keylime package (attestation)
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#106870, tc#1769823

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl);
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    # Install keylime packages
    zypper_call('in keylime-config keylime-firewalld keylime-agent keylime-tpm_cert_store keylime-registrar keylime-verifier', timeout => 240);

    # Copy the keylime configuration files to /etc/keylime if not there
    #  configuration files path changes depending on the product
    my $agent_cfg_path;
    if (is_sle "<=15-sp5") {
        # Copy the keylime configuration file to /etc if not there
        $agent_cfg_path = "/etc/keylime.conf";
        script_run("cp -n /usr$agent_cfg_path $agent_cfg_path");
    } else {
        script_run("mkdir -p /etc/keylime && cp -n /usr/etc/keylime/*.conf /etc/keylime");
        $agent_cfg_path = "/etc/keylime/agent.conf";
    }

    # Record the keylime packages' version for reference
    my $pkgs_version = script_output('rpm -qa | grep keylime');
    record_info("keylime packages version", "Current keylime packages' version:\n $pkgs_version");

    # Make sure 'keylime_verifier' and 'keylime_registrar' services can be started successfully
    systemctl('restart keylime_verifier.service');
    systemctl('is-active keylime_verifier.service');
    systemctl('restart keylime_registrar.service');
    systemctl('is-active keylime_registrar.service');

    # As test purpose, we will start keylime agent on single node
    # So setting the 'receive_revocation_ip' and 'registrar_ip' to
    # 127.0.0.1
    assert_script_run qq(sed -i 's/^registrar_ip = <REMOTE_IP>/registrar_ip = 127.0.0.1/' $agent_cfg_path);
    assert_script_run qq(sed -i 's/^receive_revocation_ip = <REMOTE_IP>/receive_revocation_ip = 127.0.0.1/' $agent_cfg_path);
    systemctl('restart keylime_agent.service');
    systemctl('is-active keylime_agent.service');
}

1;
