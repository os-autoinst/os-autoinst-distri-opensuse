# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Abstract class with business actions for License Agreement Page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::AbstractLicenseAgreementController;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init ();

sub get_license_agreement_page {
    my ($self) = @_;
    die "License Agreement Page is not displayed" unless $self->{LicenseAgreementPage}->is_shown();
    return $self->{LicenseAgreementPage};
}

sub collect_current_license_agreement_info {
    my ($self) = @_;
    return {
        language => $self->get_license_agreement_page()->get_selected_language(),
        available_languages => [$self->get_license_agreement_page()->get_available_languages()],
        text => $self->get_license_agreement_page()->get_eula_content()};
}

sub accept_license ();

sub select_language {
    my ($self, $item) = @_;
    return $self->get_license_agreement_page()->select_language($item);
}

1;
