# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods in Expert Partitioner to handle
# a generic confirmation warning containing the warning message in YRichText Widget.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Warnings::ConfirmationWarningRichText;
use strict;
use warnings;
use parent 'Installation::Warnings::ConfirmationWarning';

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{rt_warning} = $self->{app}->label({type => 'YRichText'});
    $self->{btn_ok}     = $self->{app}->button({id => 'ok'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_ok}->exist();
}

sub text {
    my ($self) = @_;
    return $self->{rt_warning}->text();
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

1;
