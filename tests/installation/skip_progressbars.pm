# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for any progress bar to disappear.
# Use TIMEOUT_SCALE so expected installation time can be adjusted
# for slower architectures.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi 'get_var';
use Installation::ProgressBarHandler::ProgressBarController;

sub run {
    my $progressbar_controller = Installation::ProgressBarHandler::ProgressBarController->new();

    my $timeout = 600 * get_var('TIMEOUT_SCALE', 1);
    $progressbar_controller->wait_progressbars_disappear({
            timeout => $timeout,
            clean_time => 40,
            interval => 2,
            message => 'System seems to be stuck in progress bars'});

}

1;
