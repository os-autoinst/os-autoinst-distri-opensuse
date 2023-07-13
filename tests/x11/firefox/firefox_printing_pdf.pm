# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox Printing - PDF Page and print range
# - Copy /data/x11/firefox/test.pdf to /home/bernhard/ffprint/
# - Launch firefox
# - Open "/home/bernhard/ffprint/test.pdf" and check result
# - Send key Ctrl-P to print the page
# - Specify the print range
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
    my $self = shift;
    my $file = "test.pdf";

    # Copy the destination file to home directory
    # Open the destination file
    # Use Ctrl-P to print the file
    $self->firefox_print2file_overview($file);

    # Test print custom pages
    my $startNum = 11;
    my $endNum = 12;
    assert_and_click "firefox-print-pdf-pages-all";
    assert_and_click "firefox-print-pdf-pages-custom";
    type_string("$startNum-$endNum");
    assert_and_click "firefox-print-pdf-$startNum-preview";
    assert_and_click "firefox-print-pdf-NextPage";
    assert_and_click "firefox-print-pdf-$endNum-preview";

    # Print to PDF
    $self->firefox_print($file);

    # Verify output file
    $self->verify_firefox_print_output($file);

    # Clean up output file
    $self->cleanup_firefox_print;
}
1;
