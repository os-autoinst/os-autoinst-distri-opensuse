# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::ComboBox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use List::MoreUtils 'firstidx';
use YuiRestClient::Action;

sub items {
    my ($self) = @_;
    my $items = $self->property('items');
    return map { $_->{label} } @{$items};
}

sub select {
    my ($self, $item) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $item);
}

sub set {
    my ($self, $item) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_ENTER_TEXT, value => $item);
}

sub value {
    my ($self) = @_;
    return $self->property('value');
}

# When combobox is enabled it does not have 'enabled' property. Only in case it is disabled, the property appears
# and equals to 'false'.
sub is_enabled {
    my ($self) = @_;
    my $is_enabled = $self->property('enabled');
    return !defined $is_enabled || $is_enabled;
}

1;
