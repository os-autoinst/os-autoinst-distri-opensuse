# SUSE's openQA tests

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

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::ComboBox - handle a ComboBox in the UI

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

  $self->{cb_language}->items();
  $self->{cb_language}->select($item);
  $self->{cb_mount_point}->set($mount_point);
  $self->{cb_language}->value();
  $self->{cb_filesystem}->is_enabled();

=head1 DESCRIPTION

=head2 Overview

Class representing a ComboBox in the UI. It can be YComboBox.

      {
        "class": "YComboBox",
        "debug_label": "NFS Version",
        "icon_base_path": "",
        "id": "nfs_version",
        "items": [
          {
            "label": "Any (Highest Available)",
            "selected": true
          },
          {
            "label": "Force NFSv3"
          }
        ],
        "items_count": 5,
        "label": "NFS &Version",
        "value": "Any (Highest Available)"
      }

=head2 Class and object methods

B<items()> - returns a list of ComboBox items

B<select($item> - selects an item in the ComboBox

B<set($item)> - enters text into the ComboBox 

B<value()> - returns the "value" property of the ComboBox

B<is_enabled()> - returns if the ComboBox is enabled or not

=cut
