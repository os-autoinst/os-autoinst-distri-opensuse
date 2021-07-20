# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles Language/Keyboard page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
    $self->{cb_keyboard_layout} = $self->{app}->combobox({id => '"Y2Country::Widgets::KeyboardSelectionCombo"'});
    $self->{tb_keyboard_test}   = $self->{app}->textbox({id => 'keyboard_test'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cb_keyboard_layout}->exist();
}

sub switch_keyboard_layout {
    my ($self, $keyboard_layout) = @_;
    $self->{cb_keyboard_layout}->select($keyboard_layout);
}

sub enter_keyboard_test {
    my ($self, $test) = @_;
    # text for test layout cannot be set correctly via rest api, so focus
    # is moved to the control with libyui and typing is done with testapi
    $self->{tb_keyboard_test}->set('');
    type_string $test;
}

sub get_keyboard_test {
    my ($self) = @_;
    $self->{tb_keyboard_test}->value();
}

1;
