# SUSE's openQA tests

package YuiRestClient::Widget::CheckBox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub check {
    my ($self) = @_;
    $self->action(action => YuiRestClient::Action::YUI_CHECK);
}

sub is_checked {
    my ($self) = @_;
    $self->property('value');
}

sub toggle {
    my ($self) = @_;
    $self->action(action => YuiRestClient::Action::YUI_TOGGLE);
}

sub uncheck {
    my ($self) = @_;
    $self->action(action => YuiRestClient::Action::YUI_UNCHECK);
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::CheckBox - handle checkboxes

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

  $self->{checkbox}->check();
  $self->{checkbox}->is_checked();
  $self->{checkbox}->toggle();
  $self->{checkbox}->uncheck();

=head1 DESCRIPTION

=head2 Overview

This class provides methods to interact with checkbox objects.

The JSON representation of a checkbox object on the server side looks like this:

    {
     "class": "YCheckBox",
     "debug_label": "Change the Time Now",
     "id": "change_now",
     "label": "Chan&ge the Time Now",
     "notify": true,
     "value": true
    }


=head2 Class and object methods 

=for Maintenance:
     It is probably a bug that methods like check(), uncheck() and toggle 
     expect a parameter $item. Therefore I left it out of the method 
     description.

B<check()> - checks a checkbox

Set "value" to "true" in YCheckBox. 

B<is_checked()> - tests if a checkbox is checked.

Returns the value property, so "true" if the checkbox is checked.

B<toggle()> - inverts the current state of the checkbox

Toggles the checkbox, therefore checked boxes become unchecked and viceversa.

B<uncheck()> - unchecks a checkbox

The value property is set to "false".

=cut
