# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::ItemSelector;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;
use YuiRestClient::Sanitizer;

sub select {
    my ($self, $item) = @_;
    my $items = $self->property('items');
    ($item) = grep { YuiRestClient::Sanitizer::sanitize($_) eq $item } map { $_->{label} } @{$items};
    return $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $item);
}

sub selected_items {
    my ($self) = @_;
    my $items = $self->property('items');
    return map { YuiRestClient::Sanitizer::sanitize($_->{label}) } grep { $_->{selected} } @{$items};
}

1;
