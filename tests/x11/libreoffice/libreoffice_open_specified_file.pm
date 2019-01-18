# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case 1503881 - Verify LibreOffice opens specified file types correctly
# Maintainer: dehai <dhkong@suse.com>

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
    x11_start_program('libreoffice');

    # open test files of different formats
    my $i = 0;
    for my $tag (qw(doc docx fodg fodp fods fodt odf odg odp ods odt pdf pptx xlsx)) {
        send_key "ctrl-o";
        wait_still_screen 3;
        send_key "ctrl-l";
        save_screenshot;
        type_string_slow "/home/$username/Documents/ooo-test-doc-types/test.$tag\n";
        wait_still_screen 3;
        assert_screen("libreoffice-test-$tag", 120);
        # Close every 3 files to reduce the VM's burden
        if ($i % 3 == 0) { send_key_until_needlematch('libreoffice-test-doc', 'alt-f4', 5, 10); }
        $i++;
    }
    send_key 'ctrl-q' unless check_screen 'generic-desktop', 0;

    #clean up
    $self->cleanup_libreoffice_recent_file();
    $self->cleanup_libreoffice_specified_file();
}
1;
