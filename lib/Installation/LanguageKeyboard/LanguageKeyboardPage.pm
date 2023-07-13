# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Language/Keyboard page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::LanguageKeyboard::LanguageKeyboardPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{cmb_keyboard_layout} = $self->{app}->combobox({id => '"Y2Country::Widgets::KeyboardSelectionCombo"'});
    $self->{txb_keyboard_test} = $self->{app}->textbox({id => 'keyboard_test'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_keyboard_layout}->exist();
}

sub switch_keyboard_layout {
    my ($self, $keyboard_layout) = @_;
    $self->{cmb_keyboard_layout}->select($keyboard_layout);
}

sub enter_keyboard_test {
    my ($self, $test) = @_;
    # text for test layout cannot be set correctly via rest api, so focus
    # is moved to the control with libyui and typing is done with testapi
    $self->{txb_keyboard_test}->set('');
    type_string $test;
}

sub get_keyboard_layout {
    my ($self) = @_;
    $self->{cmb_keyboard_layout}->value();
}

sub get_keyboard_test {
    my ($self) = @_;
    $self->{txb_keyboard_test}->value();
}

1;
