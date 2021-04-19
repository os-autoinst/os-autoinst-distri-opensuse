# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: gnote
# Summary: Test function search all notes
# - Launch gnote and check
# - Select All notes
# - Send CTRL-F, type "and", check and close gnote
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436174

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    $self->gnote_launch();
    send_key "down" if check_screen 'gnote-start-here-matched_TW';
    send_key "ret";
    $self->gnote_search_and_close('and', 'gnote-search-body-and');
}

1;
