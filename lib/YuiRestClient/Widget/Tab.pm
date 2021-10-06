# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Tab;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub select {
    my ($self, $item) = @_;
    $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $item);
}

sub selected_tab {
    my ($self) = @_;
    my $tabs = $self->property('items');
    return map { $_->{label} } grep { $_->{selected} } @{$tabs};
}

1;
