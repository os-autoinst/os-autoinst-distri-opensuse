# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice
# Summary: Case 1503881 - Verify LibreOffice opens specified file types correctly
# - Download and uncompress libreoffise sample files from datadir
# - Launch libreoffice
# - Open test files of different formats and check
# - Quit libreoffice
# - Cleanup
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    # upload libreoffice specified files for testing
    wait_still_screen;
    $self->upload_libreoffice_specified_file();

    # start libreoffice
    $self->libreoffice_start_program('libreoffice');

    # open test files of different formats
    my $i = 0;
    for my $tag (qw(doc docx fodg fodp fods fodt odf odg odp ods odt pdf pptx xlsx)) {
        send_key "ctrl-o";
        wait_still_screen 3;
        send_key "ctrl-l";
        save_screenshot;
        type_string_slow "test.$tag\n";
        wait_still_screen 3, 7;
        assert_screen("libreoffice-test-$tag", 120);
        if (match_has_tag('ooffice-tip-of-the-day')) {
            # Unselect "_S_how tips on startup", select "_O_k"
            send_key "alt-s";
            send_key "alt-o";
        }
        # close document
        send_key "ctrl-f4";
        wait_still_screen(2);
        if (check_screen("libreoffice-test-$tag")) {
            record_soft_failure("bsc#1209179 ctrl+f4 can't close libreoffice document");
            assert_and_click("close-document");
        }
        if (check_screen('generic-desktop')) {
            record_soft_failure 'bsc#1196648';
            $self->libreoffice_start_program('libreoffice');
        }
        $i++;
    }
    send_key 'ctrl-q' unless check_screen 'generic-desktop', 0;

    #clean up
    $self->cleanup_libreoffice_recent_file();
    $self->cleanup_libreoffice_specified_file();
}
1;
