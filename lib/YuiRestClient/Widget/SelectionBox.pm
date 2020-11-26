# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
