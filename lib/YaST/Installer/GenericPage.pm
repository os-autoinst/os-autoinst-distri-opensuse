# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

package YaST::Installer::GenericPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{btn_next}           = $self->{app}->button({id => 'next'});
    # $self->{debug_label} = $self->{app}->debug_label({debug_label => $debug_label}); # to be implemented as part of poo#89866
    return $self;
}

sub assert_page {
  return; # to be implemented as part of poo#89866
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
