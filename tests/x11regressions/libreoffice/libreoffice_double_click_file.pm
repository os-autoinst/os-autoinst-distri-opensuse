# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: LibreOffice: Open supported file types by double click (tc#1503778)
# Maintainer: dehai <dhkong@suse.com>

use base "x11regressiontest";
use base "x11regressiontest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # upload libreoffice specified files for testing
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
        assert_screen("libreoffice-test-$tag", 60);
        if ($tag ne 'xlsx') {
            hold_key "alt";
            send_key_until_needlematch("libreoffice-nautilus-window", "tab");
            release_key "alt";
        }
    }
    wait_screen_change {
        # close libreoffice
        send_key "ctrl-q";
    };
    wait_still_screen;
    hold_key "alt";
    send_key "tab";
    assert_screen("libreoffice-nautilus-window");
    release_key "alt";
    wait_still_screen;
    wait_screen_change {
        # close nautilus
        send_key "alt-f4";
    };
    assert_screen("generic-desktop");

    #clean up
    $self->cleanup_libreoffice_recent_file();
    $self->cleanup_libreoffice_specified_file();
}
1;
# vim: set sw=4 et:
