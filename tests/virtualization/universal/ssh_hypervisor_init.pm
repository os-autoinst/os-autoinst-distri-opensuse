# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssh coreutils ca-certificates-suse
# Summary: This test connects to hypervisor using SSH
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use virt_autotest::utils;

sub run {
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    # Backup ssh key pairs
    assert_script_run 'mkdir ~/backup && cp ~/.ssh/* ~/backup';

    # Remove old files
    assert_script_run 'rm ~/.ssh/* || true';

    # Generate the key pair
    virt_autotest::utils::ssh_setup();

    # Configure the Master socket
    assert_script_run qq(echo -e "StrictHostKeyChecking no\\nHostKeyAlgorithms ssh-rsa" > ~/.ssh/config);

    # Exchange SSH keys
    assert_script_run "ssh-keyscan $hypervisor > ~/.ssh/known_hosts";
    exec_and_insert_password "ssh-copy-id root\@$hypervisor";

    # Test the connection
    assert_script_run "ssh root\@$hypervisor hostname";

    # Copy that also for normal user
    assert_script_run "install -o $testapi::username -g users -m 0700 -d /home/$testapi::username/.ssh";
    assert_script_run "install -o $testapi::username -g users -m 0600 ~/.ssh/config ~/.ssh/id_rsa ~/.ssh/id_rsa.pub ~/.ssh/known_hosts /home/$testapi::username/.ssh/";

    virt_autotest::utils::install_default_packages();

    my ($sles_running_version, $sles_running_sp) = get_os_release();
    zypper_call("ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_" . $sles_running_version . "/SUSE:CA.repo", exitcode => [0, 4, 102, 103, 106]);
    zypper_call("in ca-certificates-suse", exitcode => [0, 102, 103, 106]);

    # Revert ssh key pairs
    assert_script_run 'rm -rf ~/.ssh/* && cp -f ~/backup/* ~/.ssh/';
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

