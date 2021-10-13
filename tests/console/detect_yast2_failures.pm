# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Decompress y2log files, as given in test data and parse for failures.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler "get_test_suite_data";
use File::Basename;

sub run {
    my $self = shift;
    select_console 'root-console';
    my $file_location = get_test_suite_data()->{file_location};
    assert_script_run("tar -xvf $file_location -C " . dirname($file_location));
    $self->investigate_yast2_failure(logs_path => dirname($file_location));
    record_info(dirname($file_location));
}

1;

