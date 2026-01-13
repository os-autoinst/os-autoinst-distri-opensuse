# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select a pattern from the bottom
#    You can pass
#    PATTERNS=yast-development
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = @_;
    $self->go_to_patterns();
    my @patterns = grep($_, split(/,/, get_required_var('PATTERNS')));
    # specific for yast development at the end of list
    wait_screen_change { send_key 'alt-end'; }
    save_screenshot;
    $self->select_visible_unselected_patterns([@patterns]);
    $self->accept_changes();
}

1;
