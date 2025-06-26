# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: The test is meant to run on FIPS enabled systems.
#
#          On SLE<16 it reconfigures ssh to workaround the issue:
#          https://bugzilla.suse.com/show_bug.cgi?id=1208797 .
#
#          Following that it will run ssh-keyscan.
#
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use testapi;
use warnings;
use utils qw(systemctl);
use version_utils qw(is_sle);
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Prepare directories just in case
    assert_script_run("mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/known_hosts");

    # Config changes as a workaround on SLE<16 OS versions
    if (is_sle('<16')) {
        my $ssh_config = <<EOF;
MACs -umac*
Ciphers -chacha20*
KexAlgorithms -curve25519*,-chacha20*
EOF
        script_output("echo '$ssh_config' >> /etc/ssh/sshd_config");
        systemctl("restart sshd");
    }

    # Perform the test
    assert_script_run("ssh-keyscan -H localhost > ~/.ssh/known_hosts");
}

1;
