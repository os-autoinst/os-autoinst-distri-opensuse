# SUSE's openQA tests

package YuiRestClient::Widget::Label;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';

sub text {
    my ($self) = @_;
    return $self->property('text');
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::Label - Handle YLabel, YLabel_Heading

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

$self->{rt_welcome}->text()

=head1 DESCRIPTION

=head2 Overview

Returns text value for the label. 

If the JSON looks like this:

   {
      "class": "YLabel",
      "debug_label": "short message",
      "label": "test label",
      "text": "text label"
   }
 
Then {app}->label({label => 'test label'})->text() will return 'text label'.

=head2 Class and object methods 

B<text()> - return text property for object.

Returns the string from the object structure that has the key 'text'.

=cut
