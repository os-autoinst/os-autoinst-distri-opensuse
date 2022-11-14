# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox Printing - Page with frames
# - Copy /data/x11/firefox/horizframetest and vertframetest to /home/bernhard/ffprint/
# - Launch firefox
# - Open "/home/bernhard/ffprint/horizframetest and vertframetest" and check result
# - Send key Ctrl-P to print the page
# - Click the Save button
# - Specify the path and name of the output file
# - Exit firefox
# - Verify the output file
# - Remove the output file
# Maintainer: Grace Wang<grace.wang@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = shift;
    my @framefiles = qw[horizframetest vertframetest];

    foreach my $framefile (@framefiles) {
        $self->firefox_print2file_overview($framefile);
        # Print to PDF
        $self->firefox_print($framefile);

        # Verify output file
        $self->verify_firefox_print_output($framefile);

        # Clean up output file
        $self->cleanup_firefox_print;
    }
}
1;
