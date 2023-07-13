# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Add-On Product
# Installation dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::AddOnProductInstallation::AddOnProductInstallationController;
use strict;
use warnings;
use Installation::AddOnProductInstallation::AddOnProductInstallationPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AddOnProductInstallation} = Installation::AddOnProductInstallation::AddOnProductInstallationPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_add_on_product_installation_page {
    my ($self) = @_;
    die 'Add-On Product Installation page is not displayed' unless $self->{AddOnProductInstallation}->is_shown();
    return $self->{AddOnProductInstallation};
}

sub add_add_on_product {
    my ($self) = @_;
    $self->get_add_on_product_installation_page()->press_add();
}

sub accept_add_on_products {
    my ($self) = @_;
    $self->get_add_on_product_installation_page()->press_next();
}

1;
