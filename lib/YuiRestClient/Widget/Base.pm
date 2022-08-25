# SUSE's openQA tests

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
    my ($self, $args) = @_;

    eval { $self->find_widgets($args) };
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
    my ($self, $args) = @_;

    $self->resolve_filter() unless $self->{filter}->is_resolved();
    return $self->{widget_controller}->find({
            filter => $self->{filter}->get_filter(),
            timeout => $args->{timeout},
            interval => $args->{interval}
    });
}

sub resolve_filter {
    my ($self, $args) = @_;

    # get json with widgets according to current filter (which does not include regex)
    my $json = $self->{widget_controller}->find({filter => $self->{filter}->get_filter()});
    # replace regex by found value in the filter
    $self->{filter}->resolve($json);
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::Base - base class for all UI objects

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS
 
  return $self->action(action => YuiRestClient::Action::YUI_PRESS);
  return $self->{rt_eula}->exist();
  my $is_enabled = $self->property('enabled');

=head1 DESCRIPTION

=head2 Overview

This class provides base methods for all UI widget classes

=head2 Class and object methods

Class attributes:

=over 4

=item * B<{widget_controller}> - reference to WidgetController class

=item * B<{filter}> - filter expression for identifying widgets

=back

Class methods:

B<new($args)> - constructor for UI objects

Arguments are I<widget_controller> and I<filter>. 

B<action(%args)> - perform action on UI widget

Arguments are a hash like C<{action =E<gt> YuiRestClient::Action::YUI_PRESS}>. 

B<exist()> - check if UI widget exists

Tries to find widget, returns 0 if widget exists.

B<propery($property)> - return JSON property value

If property does not exist the method will return C<undef>. 

B<find_widgets()> - retrieves JSON hash for the widget

The widget is specified by the C<filter> parameter on creation of the object.

=cut
