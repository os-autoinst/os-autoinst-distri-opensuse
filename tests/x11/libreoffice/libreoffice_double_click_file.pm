# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: LibreOffice: Open supported file types by double click (tc#1503778)
# Maintainer: dehai <dhkong@suse.com>

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
    send_key_until_needlematch("nautilus-Documents-matched", "right");
    send_key "ret";
    wait_still_screen(3);
    send_key_until_needlematch("libreoffice-specified-file-directory", "right");
    send_key "ret";
    wait_still_screen;

    # open test files of different formats
    for my $tag (qw(doc docx fodg fodp fods fodt odf odg odp ods odt pptx xlsx)) {
        send_key_until_needlematch("libreoffice-specified-list-$tag", "right", 50, 1);
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
