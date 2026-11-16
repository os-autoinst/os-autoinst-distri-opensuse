# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run the SELinux tools agnostic test: ls/id/ps -Z, selinuxexeccon,
#          chcon, restorecon and chcat.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#61783, poo#65672, poo#66093, poo#66096, poo#105202, poo#206877

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use agnosticTestRunner;
use version_utils 'is_sle';

sub run {
    # SLE 12 ships Python 3.4, the old SELinux tools modules cover it instead
    if (is_sle('<15')) {
        record_info('Skipped', 'Not supported on SLE 12, the old SELinux tools modules run instead');
        return;
    }
    select_serial_terminal;

    # selinux_setup installs most of these packages already, on a transactional
    # system the reboot happens only if a package was installed
    install_package('policycoreutils policycoreutils-python-utils selinux-tools', trup_reboot => 1);
    select_serial_terminal;

    for my $pkg (qw(policycoreutils policycoreutils-python-utils selinux-tools)) {
        my $version = script_output(qq(rpm -q --queryformat '%{VERSION}' $pkg));
        record_info($pkg, "version $version");
    }

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testSELinuxTools',
            domain => 'security',
            run_timeout => 600,
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
