# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'audit-remote-libvirt' test case of 'audit-test' test suite
#          as an openqa-agnostic python test
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96531

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use version_utils 'is_sle';
use virt_autotest::utils qw(check_modular_libvirt_daemons restart_modular_libvirt_daemons);
use registration 'register_product';
use agnosticTestRunner;

sub run {
    select_serial_terminal;

    install_package('libvirt virt-manager', trup_continue => 1);
    my $libvirt_version = script_output(q(rpm -q --queryformat '%{VERSION}' libvirt-daemon));
    record_info('libvirt', "version $libvirt_version");

    # Start the libvirt daemons, the agnostic test only checks which one is active
    if (is_sle('15-sp5+')) {
        assert_script_run('systemctl daemon-reload');
        restart_modular_libvirt_daemons;
        check_modular_libvirt_daemons('qemu');
    } else {
        assert_script_run('systemctl start libvirtd');
    }

    # Download the pre-installed guest image, the agnostic test expects it in place
    my $vm_L2 = get_required_var('HDD_2');
    assert_script_run('wget -c -O /var/lib/libvirt/images/nested-L2-vm.qcow2 ' . autoinst_url("/assets/hdd/$vm_L2"), 900);

    # The Full and Full-QR images are not registered, but agnosticTestRunner
    # activates PackageHub to install python3-pytest. always_rollback undoes the registration.
    register_product() if get_var('FLAVOR', '') =~ /^Full/;

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testAuditRemoteLibvirt',
            domain => 'security',
            run_timeout => 600,
        }
    );
    $test->setup()->run_test()->parse_results();
    # run_test() leaves the shell in test_dir, where the test saved the run.bash output
    upload_logs('run.log', log_name => 'audit-remote-libvirt-run.log', failok => 1);
    $test->cleanup();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
