# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Product Selection
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ProductSelection::ProductSelectionController;
use strict;
use warnings;
use YuiRestClient;
use Installation::ProductSelection::ProductSelectionPage;
use Installation::Warnings::ConfirmationWarningRichText;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{ProductSelectionPage}        = Installation::ProductSelection::ProductSelectionPage->new({app => YuiRestClient::get_app()});
    $self->{AccessBetaDistributionPopup} = Installation::Warnings::ConfirmationWarningRichText->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_product_selection_page {
    my ($self) = @_;
    die 'Product Selection page is not displayed' unless $self->{ProductSelectionPage}->is_shown();
    return $self->{ProductSelectionPage};
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
