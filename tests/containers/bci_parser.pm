
# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: bci-tests runner
#   SUSE Linux Enterprise Base Container Images (SLE BCI)
#   provides truly open, flexible and secure container images and application
#   development tools for immediate use by developers and integrators without
#   the lock-in imposed by alternative offerings.
#
#   This module is used to parse BCI results produced by bci-tests.
#   It needs to be loaded from bci_test_runner.pm after executing the tests
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use testapi;


sub run {
    my $self = @_;

    my $test_envs = get_required_var('BCI_TEST_ENVS');

    assert_script_run('cd bci-tests');
    record_info('Files', script_output('ls -lh'));

    assert_script_run("echo '<testsuites>' > result.xml");
    my @files = split(/\n/, script_output("ls -1 junit*.xml"));
    foreach my $file (@files) {
        # Parse only existing xunit results
        upload_logs($file);
        my ($env) = $file=~ /junit_(.*?).xml/;
        assert_script_run("sed -i 's/pytest/$env/' $file");
        assert_script_run("xmllint $file --xpath \"//testsuite\" >> result.xml");
    }
    assert_script_run("echo '</testsuites>' >> result.xml");
    parse_extra_log('XUnit', 'result.xml');
}

1
