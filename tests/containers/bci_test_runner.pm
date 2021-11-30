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
#   This module is used to test BCI repository and BCI container images.
#   It loops for each test environment defined by BCI_TEST_ENVS and loads the
#   test execution module.
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use XML::LibXML;
use testapi;


sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Insert "build" module first. That needs to be run before any test environment.
    my $test_envs = 'build,' . get_required_var('BCI_TEST_ENVS');

    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $root = $dom->createElement('testsuites');
    $dom->setDocumentElement($root);

    record_info('Run', "Starting the tests for the following environments:\n$test_envs");

    # Run the tests for each environment
    for my $env (split(/,/, $test_envs)) {
        my $bci_test_args = OpenQA::Test::RunArgs->new();
        $bci_test_args->{test_env} = $env;
        autotest::loadtest('tests/containers/bci_test.pm', name => $env, run_args => $bci_test_args);
    }
    autotest::loadtest('tests/containers/bci_parser.pm');
}

sub test_flags {
    return {fatal => 1};
}

1;
