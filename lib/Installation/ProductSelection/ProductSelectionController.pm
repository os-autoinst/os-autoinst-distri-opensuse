# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Product Selection
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ProductSelection::ProductSelectionController;
use strict;
use warnings;
use YuiRestClient;
use Installation::ProductSelection::ProductSelectionPage;
use Installation::Popups::OKPopup;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{ProductSelectionPage} = Installation::ProductSelection::ProductSelectionPage->new({app => YuiRestClient::get_app()});
    $self->{AccessBetaDistributionPopup} = Installation::Popups::OKPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_product_selection_page {
    my ($self) = @_;
    die 'Product Selection page is not displayed' unless $self->{ProductSelectionPage}->is_shown();
    return $self->{ProductSelectionPage};
}

sub wait_for_product_selection_page {
    my ($self, $args) = @_;
    $args->{timeout} = $args->{timeout} // YuiRestClient::get_timeout();
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{ProductSelectionPage}->is_shown({timeout => 0});
    }, %$args);
}

sub get_access_beta_distribution_popup {
    my ($self) = @_;
    die "Popup for accessing Beta Distribution is not displayed" unless $self->{AccessBetaDistributionPopup}->is_shown();
    return $self->{AccessBetaDistributionPopup};
}

sub install_product {
    my ($self, $product) = @_;
    $self->get_product_selection_page()->install_product($product);
    $self->get_product_selection_page()->press_next();
}

sub access_beta_distribution {
    my ($self) = @_;
    $self->get_access_beta_distribution_popup()->press_ok();
}

1;
