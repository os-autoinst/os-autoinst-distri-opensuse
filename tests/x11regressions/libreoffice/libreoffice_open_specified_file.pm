# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case 1503881 - Verify LibreOffice opens specified file types correctly
# Maintainer: dehai <dhkong@suse.com>

use base "x11regressiontest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # upload libreoffice specified files for testing
    wait_still_screen;
    $self->upload_libreoffice_specified_file();

    # check libreoffice dialogs setting
    x11_start_program("libreoffice");
    assert_screen("welcome-to-libreoffice");
    $self->check_libreoffice_dialogs();

    # open below qw/doc docx fodg fodp fods fodt odf odg odp ods odt pdf pptx xlsx/ to check whether can be work
    for my $tag (qw/doc docx fodg fodp fods fodt odf odg odp ods odt pdf pptx xlsx/) {
        send_key "ctrl-o";
        wait_still_screen 3;
        send_key "ctrl-l";
        save_screenshot;
        type_string "/home/$username/Documents/ooo-test-doc-types/test.$tag\n";
        wait_still_screen;
        assert_screen("libreoffice-test-$tag");
    }
    send_key "ctrl-q";
    if (!assert_screen("generic-desktop")) {
        send_key "ctrl-q";
    }

    #clean up
    $self->cleanup_libreoffice_recent_file();
    $self->cleanup_libreoffice_specified_file();
}
1;
# vim: set sw=4 et:
