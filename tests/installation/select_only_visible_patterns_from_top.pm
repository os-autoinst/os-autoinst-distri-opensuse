# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select given PATTERNS
#    You can pass
#    PATTERNS=minimal,base or
#
#    For this you need to have needles that provide base-pattern,
#    minimal-pattern...
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    $self->go_to_patterns();
    # Remove default patterns first
    $self->select_not_install_any_pattern();
    # go to the top of the list before looking for the pattern
    send_key "home";
    my @patterns = grep($_, split(/,/, get_required_var('PATTERNS')));
    # Select visible patterns
    $self->select_visible_unselected_patterns([@patterns]);
    $self->accept_changes();
}

1;
