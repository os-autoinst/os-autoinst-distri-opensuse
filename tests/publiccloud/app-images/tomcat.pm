# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic test of Tomcat image in public cloud
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi qw{record_info};

# This is a placeholder test module, which is currently being worked at.
# See https://progress.opensuse.org/issues/188607

sub run {
    record_info("TOMCAT!");
    die("This test is not yet implemented");
}

1;
