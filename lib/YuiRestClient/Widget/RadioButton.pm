# SUSE's openQA tests

package YuiRestClient::Widget::RadioButton;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub select {
    my ($self) = @_;

    return $self->action(action => YuiRestClient::Action::YUI_SELECT);
}

sub is_selected {
    my ($self) = @_;
    $self->property('value');
}

sub is_enabled {
    my ($self) = @_;
    my $is_enabled = $self->property('enabled');
    return !defined $is_enabled || $is_enabled;
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::RadioButton - Handle radio buttons

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

$self->{rb_skip_registration}->select();

$self->{$rb_name}->is_selected();

=head1 DESCRIPTION

=head2 Overview

Class representing a RadioButton in the UI. It can be YRadioButton.

    {
      "class": "YRadioButton",
      "debug_label": "Manually",
      "id": "manual",
      "label": "&Manually",
      "notify": true,
      "value": false
    }

=head2 Class and object methods

B<select()> - selects the radio button 

This will set the "value" property to true and deselect all other radio buttons
of the current group.

B<is_selected()> - returns the "value" property of the radio button

=cut
