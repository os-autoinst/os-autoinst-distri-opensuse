# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Base;

use strict;
use warnings;

sub new {
    my ($class, $args) = @_;

    return bless {
        widget_controller => $args->{widget_controller},
        filter => $args->{filter}
    }, $class;
}

sub action {
    my ($self, %args) = @_;

    $self->resolve_filter() unless $self->{filter}->is_resolved();
    # Inject filter parameters to the request
    my $params = {%args, %{$self->{filter}->get_filter()}};
    $self->{widget_controller}->send_action($params);

    return $self;
}

sub exist {
    my ($self) = @_;

    eval { $self->find_widgets() };
    return 0 if $@;
    return 1;
}

sub property {
    my ($self, $property) = @_;

    my $res = $self->find_widgets();
    # JSON always contains array if results, return first entry
    if (ref $res eq 'ARRAY' && ref $res->[0] eq 'HASH') {
        return $res->[0]->{$property};
    }

    return undef;
}

sub find_widgets {
    my ($self) = @_;

    $self->resolve_filter() unless $self->{filter}->is_resolved();
    return $self->{widget_controller}->find($self->{filter}->get_filter());
}

sub resolve_filter {
    my ($self) = @_;

    # get json with widgets according to current filter (which does not include regex)
    my $json = $self->{widget_controller}->find($self->{filter}->get_filter());
    # replace regex by found value in the filter
    $self->{filter}->resolve($json);
}

1;
