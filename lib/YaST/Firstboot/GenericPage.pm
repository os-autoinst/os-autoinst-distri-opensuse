# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handle common parts in all firstboot pages.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::GenericPage;
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
    $self->{btn_next} = $self->{app}->button({id => 'next'});
    return $self;
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
