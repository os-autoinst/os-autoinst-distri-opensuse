# SUSE's openQA tests

package YuiRestClient::Widget::Textbox;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub set {
    my ($self, $value) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_ENTER_TEXT, value => $value);
}

sub value {
    my ($self) = @_;
    return $self->property('value');
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::Textbox - handle text boxes

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

return $self->{tb_full_name}->set($full_name);

$self->{tb_keyboard_test}->value();

=head1 DESCRIPTION

=head2 Overview

Class to represent a text box. It can be YInputField. 

    {
       "class": "YInputField",
       "debug_label": "label_test",
       "hstretch": true,
       "id": "test",
       "input_max_length": 256,
       "label": "label_test",
       "password_mode": false,
       "valid_chars": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.",
       "value": ""
    }

=head2 Class and object methods

B<set($value)> - sets "value" property to $value.

B<value()> - returns the current string stored in the "value" property. 

=cut
