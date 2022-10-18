# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: bci-tests runner
#   SUSE Linux Enterprise Base Container Images (SLE BCI)
#   provides truly open, flexible and secure container images and application
#   development tools for immediate use by developers and integrators without
#   the lock-in imposed by alternative offerings.
#
#   This module is used to test BCI repository and BCI container images.
#   It performs the build step before running the actual tests
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use version_utils qw(get_os_release);
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $engine = get_required_var('CONTAINER_RUNTIME');
    my $bci_devel_repo = get_var('BCI_DEVEL_REPO');
    my $bci_timeout = get_var('BCI_TIMEOUT', 1200);

    my ($version, $sp, $host_distri) = get_os_release;

    assert_script_run('cd bci-tests');
    assert_script_run("export TOX_PARALLEL_NO_SPINNER=1");
    assert_script_run("export CONTAINER_RUNTIME=$engine");
    assert_script_run("export BCI_DEVEL_REPO=$bci_devel_repo") if $bci_devel_repo;
    my $cmd = "tox -e build -- -n auto --reruns 3 --reruns-delay 10";
    record_info('Build', $cmd);
    assert_script_run($cmd, timeout => $bci_timeout);
    upload_logs('junit_build.xml', failok => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
