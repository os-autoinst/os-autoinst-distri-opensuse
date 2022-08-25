# SUSE's openQA tests

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

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::Tree - handle a tree in the UI

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

  $self->{tree_system_view}->select($item);
  $self->{tree_system_view}->selected_item();
  $self->{tree_system_view}->get_selected_node($item);

=head1 DESCRIPTION

=head2 Overview

Class representing a tree in UI. It can be YTree.

      {
        "class": "YTree",
        "debug_label": "node_0",
        "hstretch": true,
        "hweight": 30,
        "icon_base_path": "",
        "id": "test_id",
        "items": [
          {
            "children": [
              {
                "icon_name": "icon",
                "label": "node1_1"
              },
              {
                "children": [
                  {
                    "label": "node1_2_1"
                  },
                  {
                    "label": "node1_2_2",
                    "selected": true
                  }
                ],
                "icon_name": "icon",
                "label": "node1_2"
              }
            ],
            "icon_name": "icon",
            "label": "node1",
          },
          {
            "icon_name": "icon",
            "label": "node2"
          }
        ],
        "items_count": 2,
        "label": "node_0",
        "notify": true,
        "vstretch": true
      }

=head2 Class and object methods

B<select($path)> - selects item that is specified by $path. 

The parameter $path is defining the label property of the node in the tree.

B<selected_item()> - returns the path to the selected item

The returned path contains the node labels (separated by "|") in the branch 
of the tree were the selected item is found. So in the example tree above 
the method would return "node1|node1_2|node21_2_2"

B<get_selected_node( %args )> - return path to selected node

Args has 2 named parameters:

=over 4

* item => the property that we're looking for, eg. property('items').

* path => the path starting with a node

The path parameter is used for recursion in this function. 

=cut

