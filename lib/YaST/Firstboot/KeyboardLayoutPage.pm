# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for
# Firstboot Keyboard Layout Configuration
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::KeyboardLayoutPage;
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
    $self->{btn_next}             = $self->{app}->button({id => 'next'});
    $self->{isel_keyboard_layout} = $self->{app}->itemselector({id => 'layout_list'});
    return $self;
}

sub get_keyboard_layout {
    my ($self) = @_;
    return ($self->{isel_keyboard_layout}->selected_items())[0];
}

sub is_shown {
    my ($self) = @_;
    return $self->{isel_keyboard_layout}->exist();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
