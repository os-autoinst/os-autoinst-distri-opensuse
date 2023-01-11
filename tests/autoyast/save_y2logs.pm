# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: run save_y2logs and upload the generated tar.bz2
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>


use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    my $self = shift;
    assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
    upload_logs '/tmp/y2logs.tar.bz2';
}

1;
