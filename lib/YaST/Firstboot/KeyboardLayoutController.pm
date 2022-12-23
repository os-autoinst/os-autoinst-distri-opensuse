# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST Firstboot Keyboard Layout
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::KeyboardLayoutController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::KeyboardLayoutPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{KeyboardLayoutPage} = YaST::Firstboot::KeyboardLayoutPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_keyboard_layout_page {
    my ($self) = @_;
    die "Keyboard layout page is not shown" unless $self->{KeyboardLayoutPage}->is_shown();
    return $self->{KeyboardLayoutPage};
}

sub collect_current_keyboard_layout_info {
    my ($self) = @_;
    return {keyboard_layout => $self->get_keyboard_layout_page()->get_keyboard_layout()};
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_keyboard_layout_page()->press_next();
}

1;
