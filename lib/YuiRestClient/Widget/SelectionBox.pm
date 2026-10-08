# SUSE's openQA tests

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

sub selected_items {
    my ($self) = @_;
    my $items = $self->property('items');
    return map { $_->{label} } grep { $_->{selected} } @{$items};
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::SelectionBox - Class representing a selection box in the UI. It can be YSelectionBox

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Overview

Handles a selection box.

      {
        "class" : "YSelectionBox",
        "debug_label" : "selection box title",
        "hstretch" : true,
        "icon_base_path" : "",
        "id" : "test_id",
        "items" :
        [
          {
            "label" : "selection 1",
            "selected" : true
          },
          {
            "label" : "selection 2"
          },
          {
            "label" : "selection 3"
          }
        ],
        "items_count" : 3,
        "label" : "&selection box title",
        "vstretch" : true
      }

=head2 Class and object methods

B<select($item)> - Select item in a SelectionBox object.

This action puts the item in focus (i.e highlights it), but does not check a checkbox associated with the item.
The item is identified by its label.

B<check($item)> - Check checkbox for an item in a SelectionBox object.

The item is identified by its label.

B<uncheck($item)> - Uncheck checkbox for an item in a SelectionBox object.

The item is identified by its label.

B<items()> - returns a map of available items in the SelectionBox object.

B<selected_items()> - get a list of selected items

This method returns an array with all the labels of items that are selected in the
current class object. 

=cut
