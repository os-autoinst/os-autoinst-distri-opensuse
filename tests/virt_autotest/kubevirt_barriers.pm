# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run kubevirt test suite
# Maintainer: Nan Zhang <nan.zhang@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;

sub run {
    barrier_create('kubevirt_test_setup', 2);
    barrier_create('rke2_server_start_ready', 2);
    barrier_create('rke2_server_restart_complete', 2);
    barrier_create('kubevirt_test_done', 2);
}

1;
