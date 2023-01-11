# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Selection dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::AddOnProduct::AddOnProductController;
use strict;
use warnings;
use Installation::AddOnProduct::AddOnProductPage;
use Installation::AddOnProduct::AdditionalProductPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AddOnProduct} = Installation::AddOnProduct::AddOnProductPage->new({app => YuiRestClient::get_app()});
    $self->{AdditionalProductPage} = Installation::AddOnProduct::AdditionalProductPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_add_on_product_page {
    my ($self) = @_;
    die 'Add On Product page is not displayed' unless $self->{AddOnProduct}->is_shown();
    return $self->{AddOnProduct};
}

sub get_additional_product_page {
    my ($self) = @_;
    die 'Additional Product page is not displayed' unless $self->{AdditionalProductPage}->is_shown();
    return $self->{AdditionalProductPage};
}

sub confirm_like_additional_add_on {
    my ($self) = @_;
    $self->get_add_on_product_page()->confirm_like_additional_add_on();
}

sub accept_current_media_type_selection {
    my ($self) = @_;
    $self->get_add_on_product_page()->press_next();
}

sub add_selected_products {
    my ($self) = @_;
    $self->get_additional_product_page()->press_add_selected_products();
}

1;
