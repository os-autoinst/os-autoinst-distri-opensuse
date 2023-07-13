# SUSE's openQA tests

package YuiRestClient::Widget::ProgressBar;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';

sub value {
    my ($self) = @_;
    return $self->property('value');
}

sub max_value {
    my ($self) = @_;
    return $self->property('max_value');
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::ProgressBar - handle progress bars

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

$self->{pba_total_packages}->value();
$self->{pba_total_packages}->max_value();

=head1 DESCRIPTION

=head2 Overview

Class to represent a progress bar. It can be YProgressBar. 

    {
       "class": "YProgressBar",
       "hstretch" : true,
       "id" : "initProg",
       "label" : "Disk",
       "max_value" : 1000,
       "value" : 666
    }

=head2 Class and object methods

B<value()> - returns the current string stored in the "value" property. 
B<max_value()> - returns the current string stored in the "max_value" property. 

=cut
