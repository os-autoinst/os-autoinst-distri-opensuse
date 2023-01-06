# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST Firstboot Host Name Configuration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::HostNameController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::HostNamePage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{HostNamePage} = YaST::Firstboot::HostNamePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_host_name_page {
    my ($self) = @_;
    die "Host Name page is not shown" unless $self->{HostNamePage}->is_shown();
    return $self->{HostNamePage};
}

sub collect_current_host_name_info {
    my ($self) = @_;
    return {
        static_hostname => $self->get_host_name_page()->get_static_hostname(),
        set_hostname_via_DHCP => $self->get_host_name_page()->get_set_hostname_via_DHCP()};
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_host_name_page()->press_next();
}

1;
