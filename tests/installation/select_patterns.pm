# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select given PATTERNS
#    You can pass
#    PATTERNS=minimal,base or
#    PATTERNS=all to select all of them
#    PATTERNS=default,web,-x11,-gnome to keep the default but add web and
#    remove x11 and gnome
#
#    For this you need to have needles that provide pattern-base,
#    pattern-minimal...
#    additional to the on-pattern tag
# Maintainer: slindomansilla <slindomansilla@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils 'type_string_slow';

sub run {
    my ($self) = @_;
    $self->go_to_patterns();
    $self->process_patterns();
    $self->accept_changes();
}

1;
