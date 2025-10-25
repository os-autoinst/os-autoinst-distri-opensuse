# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Public Cloud - Resource Cleanup
# This module deletes resources from cloud:
# - Free up cloud resources
# - Avoid additional cost
# - Clean up the environment
# It's also implemented as a post_fail_hook to ensure resources
# are deleted even if a test module fails.

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use sles4sap::aws_cli;


sub run {
    my ($self) = @_;

    select_serial_terminal;
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
