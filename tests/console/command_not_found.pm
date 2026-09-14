# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: command-not-found
# Summary: check that command-not-found works as intended, http://bugzilla.suse.com/show_bug.cgi?id=952496
# - install command-not-found in textmode
# - as a normal user
#     check cnf returns expected output how to install package
#     check cnf returns expected output where can be package found
# Maintainer: QE Core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use version_utils 'is_sle';
use package_utils qw(install_package uninstall_package);
use registration qw(add_suseconnect_product remove_suseconnect_product);
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    my $not_installed_pkg = is_sle(">=16.0") ? 'tmux' : 'iftop';    # iftop is not available on SLES16

    select_serial_terminal;
    uninstall_package("$not_installed_pkg", trup_reboot => 1) if (script_run("which $not_installed_pkg") == 0);

    # command-not-found is part of the enhanced_base pattern, missing in textmode
    install_package('command-not-found', trup_continue => 1, trup_reboot => 1) if (check_var('DESKTOP', 'textmode'));

    # select user-console; for one we want to be sure cnf works for a user, 2nd assert_script_run does not work in root-console
    select_console 'user-console';

    save_screenshot;
    assert_script_run(qq{echo "\$(cnf $not_installed_pkg 2>&1 | tee /dev/stderr)" | grep -q "sudo zypper install $not_installed_pkg"});
    save_screenshot;

    if (is_sle('15+')) {
        # test if cnf works for non-registered modules
        assert_script_run "! rpm -q evince";    # evince is in desktop module
        assert_script_run(qq{echo "\$(cnf evince 2>&1 | tee /dev/stderr)" | grep -q "The program 'evince' can be found in following packages"});
    }

    select_serial_terminal;
    install_package("$not_installed_pkg", trup_continue => 1, trup_reboot => 1);
    uninstall_package("$not_installed_pkg", trup_continue => 1, trup_reboot => 1);
}

1;
