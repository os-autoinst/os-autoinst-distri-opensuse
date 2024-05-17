# Gnote tests
#
# Copyright 2016 SUSE LLC

# SPDX-License-Identifier: FSFAP

# Package: gnote
# Summary: Gnote: Search for text in title of notes
# - Launch gnote and check
# - Select all notes
# - Send CTRL-F, type "here", check and close gnote
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>
# Tags: tc#1503894

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    $self->gnote_launch();
    $self->gnote_search_and_close('here', 'gnote-search-title-here');
}

1;
