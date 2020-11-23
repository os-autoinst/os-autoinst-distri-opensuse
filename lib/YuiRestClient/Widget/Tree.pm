# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
