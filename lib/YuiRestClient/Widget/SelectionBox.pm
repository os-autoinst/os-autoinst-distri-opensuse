# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::SelectionBox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use List::MoreUtils 'firstidx';
use YuiRestClient::Action;

sub select {
    my ($self, $item) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $item);
}

sub check {
    my ($self, $item) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_CHECK, value => $item);
}

sub uncheck {
    my ($self, $item) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_UNCHECK, value => $item);
}

sub items {
    my ($self) = @_;

    my $items = $self->property('items');
    return map { $_->{label} } @{$items};
}

1;
