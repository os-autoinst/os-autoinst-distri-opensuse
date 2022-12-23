# SUSE's openQA tests

package YuiRestClient::Widget::Table;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use List::MoreUtils 'firstidx';
use YuiRestClient::Action;

sub select {
    my ($self, %args) = @_;
    my %params = (action => YuiRestClient::Action::YUI_SELECT);

    if (exists $args{value}) {
        $params{value} = $args{value};
        $params{column} = $self->get_index($args{column}) if $args{column};
    }
    elsif (exists $args{row}) {
        $params{row} = $args{row};
    }

    $self->action(%params);

    return $self;
}

sub header {
    my ($self) = @_;

    $self->property('header');
}

sub items {
    my ($self) = @_;

    return (map { $_->{labels} } @{$self->property('items')});
}

sub get_index {
    my ($self, $column) = @_;
    my @header = @{$self->header()};

    return firstidx { $_ eq $column } @header;
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::Table - Handle table objects in the UI

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

  $self->{tbl_available_devices}->select(value => $device);

=head1 DESCRIPTION

=head2 Overview

Class representing a table in the UI. It can be YTable.

        {
          "class": "YTable",
          "columns": 4,
          "header": [
            "header1",
            "header2",
            "header3",
            "header4"
          ],
          "id": "test_id",
          "items": [
              {
                  "labels": [
                     "test.item.1",
                     "",
                     "",
                     ""
                  ],
                  "selected": true
              },
              {
                  "labels": [
                      "test.item.2",
                      "",
                      "",
                      ""
                  ]
              }
          ],
          "items_count": 2
        }

=head2 Class and object methods

B<select(%args)> - select a row in a table

Sends action to select a row in a table. Row can be selected either by
cell value in the column (first column will be used by default), or by
row number directly. If both are provided, value will be used.
NOTE: row number corresponds to the position of the
item in the list of column values which might differ to the display order.

The %args has has the following keys:

=over 4

=item * B<{value}> - [String] value to select in the table

=item * B<{column}> - [String] column name where value is present

=item * B<{row}> - [Numeric] row number to select in the table

=back

Example: Select row with value "test.item.2" for column "header1" in table 

  $self->{table}->select(value => 'test.item.2', column => 'header1');

Example: Select row number 3

  $self->{table}->select(row => 3);

B<header()> - returns array with the column names

B<items()> - returns all table items

For the example table above this function would return

  (["test.item.1", "", ""],["Test.item.2", "", ""])

B<get_index($column)> - return the index of the column 

The parameter $column specifies the header string that we're looking for. 

=cut
