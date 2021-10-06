# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Do some actions prior to the shutdown
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run {
    # We need to stop the cluster stack to avoid fencing during shutdown
    assert_script_run("crm cluster stop");
}

1;
