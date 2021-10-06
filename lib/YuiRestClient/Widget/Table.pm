# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
        $params{value}  = $args{value};
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
