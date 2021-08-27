# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Abstract class with business actions for License Agreement Page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
        language            => $self->get_license_agreement_page()->get_selected_language(),
        available_languages => [$self->get_license_agreement_page()->get_available_languages()],
        text                => $self->get_license_agreement_page()->get_eula_content()};
}

sub accept_license ();

sub select_language {
    my ($self, $item) = @_;
    return $self->get_license_agreement_page()->select_language($item);
}

1;
