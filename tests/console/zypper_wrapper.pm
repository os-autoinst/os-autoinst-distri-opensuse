# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper transactional-wrapper
# Summary: zypper should be able to handle transactional systems directly
#
# Transactional Wrapper:
# transactional-wrapper is expected to be run as a child process of the tool which needs writing to read-only
# part of the system. It does not require any parameters (it can receive the command-line if its parent process
# from the /proc filesystem.  This means that the respective tool does not need to replicate the commands.
#
# It can optionally provide configuration for the respective tool, either via file or via command-line parameters,
# to specify behavior on exit codes.
#
# The transactional wrapper - if installed - can be disabled or enabled via configuration file. Additionally,
# it can define the behavior on successful transaction:
# - call transactional-update apply
# - do nothing (requires user to activate the snapshot before using next transactional command
# - reboot immediately
# - soft-reboot immediately
# - reboot via kexec immediately
#
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use transactional;
use utils 'zypper_call';

sub run {
    select_serial_terminal;

    my $pkg = 'zsh';

    install_package('transactional-wrapper', trup_reboot => 1);

    # Copy config file to /etc/ to make changes in the configuration
    assert_script_run 'cp /usr/etc/transactional-wrapper.conf /etc';

    # Try action 'info' [default one] after installaion
    validate_script_output("zypper -n install $pkg", sub { m/Please reboot your machine to activate the changes and avoid data loss/ });
    die "$pkg will not be seen without reboot" if (script_run("rpm -q $pkg") == 0);
    check_reboot_changes;
    assert_script_run "rpm -q $pkg";
    zypper_call "rm $pkg";
    check_reboot_changes;

    # Try action 'apply' after installaion
    assert_script_run qq(sed -i 's/ACTION="info"/ACTION="apply"/' /etc/transactional-wrapper.conf);
    validate_script_output("zypper -n install $pkg", sub { m/Applied default snapshot as new base for running system/ });
    die "$pkg will be seen in apply action" unless (script_run("rpm -q $pkg") == 0);
    zypper_call "rm $pkg";
    die "$pkg will not be seen in apply action" if (script_run("rpm -q $pkg") == 0);
}

1;
