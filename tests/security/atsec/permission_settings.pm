# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Permission settings of relevant configuration files' test case of ATSec test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#111518

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    my $output = script_output('find -L /etc -perm -g+w,o+w');

    # This test is to verify that important configuration files are protected
    # against access by unauthorized users. The result shows files that are softlinks
    # or the random device is allowed exception to the initial result expectation.
    foreach my $file (split('\n', $output)) {
        my $file_detail = script_output("readlink $file");
        if ($file_detail !~ /(\/dev\/null|\/dev\/random)/) {

            # The file is not a softlink or doesn't link to expected device
            record_info($file, $file_detail, result => 'fail');
            $self->result('fail');
        }
    }
}

1;
