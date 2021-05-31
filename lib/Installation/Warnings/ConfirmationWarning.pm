# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods to handle a generic
# confirmation warning.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Warnings::ConfirmationWarning;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_yes}     = $self->{app}->button({id => 'yes'});
    $self->{btn_no}      = $self->{app}->button({id => 'no'});
    $self->{lbl_warning} = $self->{app}->label({type => 'YLabel'});
    return $self;
}

sub press_yes {
    my ($self) = @_;
    return $self->{btn_yes}->click();
}

sub press_no {
    my ($self) = @_;
    return $self->{btn_no}->click();
}

sub text {
    my ($self) = @_;
    return $self->{lbl_warning}->text();
}

1;
