# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act with Registration page
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Registration::RegisteredSystemPage;
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
    my ($self) = @_;
    $self->{btn_next}              = $self->{app}->button({id => 'next'});
    $self->{lbl_system_registered} = $self->{app}->label({label => 'The system is already registered.'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_system_registered}->exist();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
