# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Language/Keyboard
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::LanguageKeyboard::LanguageKeyboardController;
use strict;
use warnings;
use YuiRestClient;
use Installation::LanguageKeyboard::LanguageKeyboardPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{LanguageKeyboardPage} = Installation::LanguageKeyboard::LanguageKeyboardPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_language_keyboard_page {
    my ($self) = @_;
    die 'Language, Keyboard page is not displayed' unless $self->{LanguageKeyboardPage}->is_shown();
    return $self->{LanguageKeyboardPage};
}

sub switch_keyboard_layout {
    my ($self, $keyboard_layout) = @_;
    $self->get_language_keyboard_page()->switch_keyboard_layout($keyboard_layout);
}

sub enter_keyboard_test {
    my ($self, $test) = @_;
    $self->get_language_keyboard_page()->enter_keyboard_test($test);
}

sub get_keyboard_test {
    my ($self) = @_;
    $self->get_language_keyboard_page()->get_keyboard_test();
}

sub wait_for_keyboard_layout_to_be_selected {
    my ($self, $keyboard_layout) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->get_language_keyboard_page()->get_keyboard_layout() eq $keyboard_layout;
    });
}

1;
