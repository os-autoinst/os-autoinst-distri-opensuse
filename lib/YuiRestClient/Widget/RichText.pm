# SUSE's openQA tests

package YuiRestClient::Widget::RichText;

use strict;
use warnings;
use YuiRestClient::Action;

use parent 'YuiRestClient::Widget::Base';

sub text {
    my ($self) = @_;
    return $self->property('text');
}

sub activate_link {
    my ($self, $link) = @_;
    return $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $link);
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::RichText - handle rich text objects

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

return $self->{rt_welcome}->text();

return $self->{rt_items}->activate_link($module_full_name);

=head1 DESCRIPTION

=head2 Overview

Class to work with YRichText objects. Rich text objects are

    {
         "class": "YRichText",
         "enabled": false,
         "hstretch": true,
         "id": "test",
         "text": "<small>Select something here</small>",
         "vstretch": true,
         "vweight": 25
    }

=head2 Class and object methods

B<text()> - return the value of the "text" property.

B<activate_link($link)> - activates a link in the rich text

If the rich text field contains a link, then this link can be activated with
this function. 

=cut
