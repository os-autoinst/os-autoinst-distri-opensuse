# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Tree;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub select {
    my ($self, $path) = @_;

    $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $path);

    return $self;
}

sub selected_item {
    my ($self) = @_;

    return $self->get_selected_node(items => $self->property('items'), path => '');
}

sub get_selected_node {
    my ($self, %args) = @_;

    foreach (@{$args{items}}) {
        my $path = $args{path} . $_->{label};
        if (defined $_->{selected} && $_->{selected} eq 'true') {
            return $path;
        }
        if ($_->{children}) {
            return $self->get_selected_node(items => $_->{children}, path => $path . '|');
        }
    }

    return undef;
}

1;
