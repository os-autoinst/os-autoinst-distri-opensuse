# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for
# Firstboot Keyboard Layout Configuration
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::KeyboardLayoutPage;
use parent 'Installation::Navigation::NavigationBase';
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
    $self->SUPER::init();
    $self->{its_keyboard_layout} = $self->{app}->itemselector({id => 'layout_list'});
    return $self;
}

sub get_keyboard_layout {
    my ($self) = @_;
    return ($self->{its_keyboard_layout}->selected_items())[0];
}

sub is_shown {
    my ($self) = @_;
    return $self->{its_keyboard_layout}->exist();
}

1;
