# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Language and Keyboard
#          Layout dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::LanguageAndKeyboardLayoutController;
use strict;
use warnings;
use YaST::Firstboot::LanguageAndKeyboardLayoutPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{LanguageAndKeyboardLayoutPage} = YaST::Firstboot::LanguageAndKeyboardLayoutPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_language_and_keyboard_layout_page {
    my ($self) = @_;
    die "Language and Keyboard Layout page is not shown" unless $self->{LanguageAndKeyboardLayoutPage}->is_shown();
    return $self->{LanguageAndKeyboardLayoutPage};
}

sub collect_current_language_and_keyboard_layout_info {
    my ($self) = @_;
    return {
        language        => $self->get_language_and_keyboard_layout_page()->get_language(),
        keyboard_layout => $self->get_language_and_keyboard_layout_page()->get_keyboard_layout()};
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_language_and_keyboard_layout_page()->press_next();
}

1;
