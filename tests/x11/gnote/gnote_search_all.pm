# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnote
# Summary: Test function search all notes
# - Launch gnote and check
# - Send CTRL-F, type "welcome" and check result
# - Close gnote
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436174

use base "x11test";
use testapi;


sub run {
    my ($self) = @_;
    $self->gnote_launch();
    $self->gnote_search_and_close('welcome', 'gnote-search-welcome');
}

1;
