# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for
# Firstboot Language and Keyboard Configuration
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
    $self->{cmb_keyboard_layout} = $self->{app}->combobox({id => 'keyboard'});
    $self->{cmb_language} = $self->{app}->combobox({id => 'language'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_language}->exist();
}

sub get_language {
    my ($self) = @_;
    return $self->{cmb_language}->value();
}

sub get_keyboard_layout {
    my ($self) = @_;
    return $self->{cmb_keyboard_layout}->value();
}

1;
