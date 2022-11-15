# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox Printing - Images
# - Copy from /data/x11/firefox/ to /home/bernhard/ffprint/
# - Launch firefox and open different image types
# - Print to file
# - Exit firefox
# - Verify the output file
# - Remove the output file
# Maintainer: Grace Wang<grace.wang@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my $self = shift;
    my @picturefiles = qw[large.gif large.jpg small.gif small.jpg];

    foreach my $picurefile (@picturefiles) {
        $self->firefox_print2file_overview($picurefile);
        # Print to PDF
        $self->firefox_print($picurefile);

        # Verify output file
        $self->verify_firefox_print_output($picurefile);
        # Clean up output file
        $self->cleanup_firefox_print;
    }
}
1;
