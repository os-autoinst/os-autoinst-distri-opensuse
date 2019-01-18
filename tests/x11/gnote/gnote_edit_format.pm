# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test gnote note format
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436163

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    $self->gnote_start_with_new_note;
    type_string "opensuse\n";
    send_key "ctrl-h";    #hightlight on
    type_string "opensuse\n";
    send_key "ctrl-b";    #bold on
    type_string "opensuse\n";
    send_key "ctrl-b";    #bold off
    send_key "ctrl-h";    #hightlight off
    send_key "ctrl-i";    #italic on
    type_string "opensuse\n";
    send_key "ctrl-s";    #strikeline on
    type_string "opensuse\n";
    send_key "ctrl-s";    #strikeline off
    send_key "ctrl-i";    #italic off
    assert_screen 'gnote-edit-format', 5;

    $self->cleanup_gnote('gnote-new-note-matched');
}

1;
