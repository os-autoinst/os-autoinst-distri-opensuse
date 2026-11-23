# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run eCryptfs agnostic test mounting an encrypted directory with
#          every supported cipher, expecting EPERM in FIPS kernel mode.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#110355 poo#207477

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use version_utils qw(is_sle is_leap);
use agnosticTestRunner;

sub run {
    select_serial_terminal;

    if (is_sle('>=16.0') || is_leap('>=16.0')) {
        record_info('TEST SKIPPED', 'ecryptfs-utils package not present in SLE 16 / Leap 16');
        return;
    }
    # On transactional systems reboot into the new snapshot, so the package is
    # available for the rpm query and the test below.
    install_package('ecryptfs-utils', trup_reboot => 1);
    my $ecryptfs_version = script_output(q(rpm -q --queryformat '%{VERSION}' ecryptfs-utils));
    record_info('ecryptfs-utils', "version $ecryptfs_version");

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testEcryptfs',
            domain => 'security',
            # Each of the 6 ciphers can use up to 10 s for mount and 10 s for
            # umount before it fails, keep room for that and pytest start-up.
            run_timeout => 240,
        }
    );
    $test->setup();
    # Exported after setup because installing pytest may reboot transactional
    # systems. In FIPS kernel mode the test then fails if the kernel does not
    # run in FIPS mode, instead of testing the normal path.
    my $expect_fips_kernel = (get_var('FIPS_ENABLED') && !get_var('FIPS_ENV_MODE')) ? 1 : 0;
    assert_script_run("export ECRYPTFS_EXPECT_FIPS_KERNEL=$expect_fips_kernel");
    $test->run_test()->parse_results()->cleanup();
}

1;
