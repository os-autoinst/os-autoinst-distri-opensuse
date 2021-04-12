# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for firstboot wizard.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::FirstbootController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::GenericPage;
use YaST::Firstboot::LANSetupPage;
use YaST::Firstboot::KeyboardLayoutPage;
use YaST::Firstboot::NTPClientPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{GenericPage}  = YaST::Firstboot::GenericPage->new({app => YuiRestClient::get_app()});
    $self->{LanPage}      = YaST::Firstboot::LANSetupPage->new({app => YuiRestClient::get_app()});
    $self->{KeyboardPage} = YaST::Firstboot::KeyboardLayoutPage->new({app => YuiRestClient::get_app()});
    $self->{NTPPage}      = YaST::Firstboot::NTPClientPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_generic_page {
    my ($self) = @_;
    $self->{GenericPage};
}

sub get_NTP_page {
    my ($self) = @_;
    die "NTP layout page is not shown" unless $self->{NTPPage}->is_shown();
    return $self->{NTPPage};
}

sub get_keyboard_page {
    my ($self) = @_;
    die "Keyboard layout page is not shown" unless $self->{KeyboardPage}->is_shown();
    return $self->{KeyboardPage};
}

sub get_lan_page {
    my ($self) = @_;
    die "LAN setup page is not shown" unless $self->{LanPage}->is_shown();
    return $self->{LanPage};
}

sub setup_LAN {
    my ($self) = @_;
    $self->get_lan_page->press_next();
}

sub setup_NTP {
    my ($self) = @_;
    $self->get_NTP_page->press_next();
}

sub setup_keyboard {
    my ($self) = @_;
    $self->get_keyboard_page->press_next();
}

sub press_next {
    my ($self) = @_;
    $self->get_generic_page->press_next();
}

1;
