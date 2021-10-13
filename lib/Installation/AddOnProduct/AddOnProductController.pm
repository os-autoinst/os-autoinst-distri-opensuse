# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Module Selection dialog.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AddOnProduct::AddOnProductController;
use strict;
use warnings;
use Installation::AddOnProduct::AddOnProductPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AddOnProduct} = Installation::AddOnProduct::AddOnProductPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_add_on_product_page {
    my ($self) = @_;
    die "Add On Product page is not displayed" unless $self->{AddOnProduct}->is_shown();
    return $self->{AddOnProduct};
}

sub skip_install_addons {
    my ($self) = @_;
    $self->get_add_on_product_page()->press_next();
}

1;
