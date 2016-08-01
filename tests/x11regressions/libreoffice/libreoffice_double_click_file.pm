# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1503778  - LibreOffice: Open supported file types by double click.

use base "x11regressiontest";
use base "x11regressiontest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # upload libreoffice specified files for testing
    wait_still_screen;
    $self->upload_libreoffice_specified_file();

    # open gnome file manager- nautilus for testing
    x11_start_program("nautilus");
    assert_screen("nautilus-launched");
    send_key_until_needlematch("nautilus-Documents-matched", "right");
    send_key "ret";
    wait_still_screen(3);
    send_key_until_needlematch("libreoffice-specified-file-directory", "right");
    send_key "ret";
    wait_still_screen;

    # double click the below qw/doc docx fodg fodp fods fodt odf odg odp ods odt pptx xlsx/ to check whether can be work
    for my $tag (qw/doc docx fodg fodp fods fodt odf odg odp ods odt pptx xlsx/) {
        send_key_until_needlematch("libreoffice-specified-list-$tag", "right", 50, 1);
        assert_and_dclick("libreoffice-specified-list-$tag");
        wait_still_screen;
        assert_screen("libreoffice-test-$tag");
        if ($tag ne 'xlsx') {
            hold_key "alt";
            send_key_until_needlematch("libreoffice-nautilus-window", "tab");
            release_key "alt";
        }
    }
    send_key "ctrl-q";
    hold_key "alt";
    send_key "tab";
    assert_screen("libreoffice-nautilus-window");
    release_key "alt";
    send_key "alt-f4";
    if (!assert_screen("generic-desktop")) {
        send_key "ctrl-q";
        hold_key "alt";
        send_key "tab";
        assert_screen("libreoffice-nautilus-window");
        release_key "alt";
        send_key "alt-f4";
    }

    #clean up
    $self->cleanup_libreoffice_recent_file();
    $self->cleanup_libreoffice_specified_file();
}
1;
# vim: set sw=4 et:
