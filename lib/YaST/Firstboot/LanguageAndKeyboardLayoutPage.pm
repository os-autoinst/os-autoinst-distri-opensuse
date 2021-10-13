# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for
# Firstboot Language and Keyboard Configuration
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::LanguageAndKeyboardLayoutPage;
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
    $self->{cb_keyboard_layout} = $self->{app}->combobox({id => 'keyboard'});
    $self->{cb_language} = $self->{app}->combobox({id => 'language'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cb_language}->exist();
}

sub get_language {
    my ($self) = @_;
    return $self->{cb_language}->value();
}

sub get_keyboard_layout {
    my ($self) = @_;
    return $self->{cb_keyboard_layout}->value();
}

1;
