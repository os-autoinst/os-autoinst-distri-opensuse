# Gnote tests
#
# Copyright © 2016 SUSE LLC

#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gnote: Search for text in title of notes
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1503894

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    $self->gnote_launch();
    send_key "down" if check_screen 'gnote-start-here-matched_TW';
    send_key "ret";
    $self->gnote_search_and_close('here', 'gnote-search-title-here');
}

1;
