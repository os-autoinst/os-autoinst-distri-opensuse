# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Additional Products page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AddOnProduct::AdditionalProductPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{btn_add_selected_products} = $self->{app}->button({id => 'ok'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_add_selected_products}->exist();
}

sub press_add_selected_products {
    my ($self) = @_;
    return $self->{btn_add_selected_products}->click();
}

1;
