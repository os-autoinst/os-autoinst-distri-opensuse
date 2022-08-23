# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus libreoffice
# Summary: LibreOffice: Open supported file types by double click (tc#1503778)
# - Download sample files from datadir
# - Launch nautilus, open directory containing test files
# - Open each file from the following formats: doc docx fodg fodp fods fodt odf
#   odg odp ods odt pptx xlsx and check
# - Quit libreoffice
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub run {
    my $self = shift;

    # upload libreoffice specified files for testing
    $self->upload_libreoffice_specified_file();

    # open gnome file manager- nautilus for testing
    x11_start_program('nautilus');
    assert_and_dclick "nautilus-Documents-matched";
    wait_still_screen(3);

    # open test files of different formats
    for my $tag (qw(doc docx fodg fodp fods fodt odf odg odp ods odt pptx xlsx)) {
        send_key_until_needlematch("libreoffice-specified-list-$tag", "right", 51, 1);
        assert_and_dclick("libreoffice-specified-list-$tag");
        assert_screen("libreoffice-test-$tag", 90);
        if (is_sle '15+') {
            send_key 'alt-f4';
        }
        else {
            send_key 'ctrl-q';
        }
    }
    send_key 'ctrl-q' unless check_screen 'generic-desktop', 0;

    #clean up
    $self->cleanup_libreoffice_recent_file();
    $self->cleanup_libreoffice_specified_file();
}
1;
