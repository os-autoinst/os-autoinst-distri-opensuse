# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act on license agreement page of
#          the installer for SLE products
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::License::SLE::LicenseAgreementPage;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_next}          = $self->{app}->button({id => 'next'});
    $self->{cb_accept_license} = $self->{app}->checkbox({id => '"Y2Packager::Widgets::ProductLicenseConfirmation"'});
    $self->{cb_eula_language}  = $self->{app}->combobox({id => '"simple_language_selection"'});
    $self->{txt_eula}          = $self->{app}->richtext({id => '"CWM::RichText"'});

    return $self;
}

sub check_accept_license {
    my ($self) = @_;
    return $self->{cb_accept_license}->check();
}

sub get_available_languages {
    my ($self) = @_;
    return $self->{cb_eula_language}->items();
}

sub get_eula_content {
    my ($self) = @_;
    return $self->{txt_eula}->text();
}

sub get_selected_language {
    my ($self) = @_;
    return $self->{cb_eula_language}->value();
}

sub is_shown {
    my ($self) = @_;
    return $self->{txt_eula}->exist();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

sub select_language {
    my ($self, $item) = @_;
    return $self->{cb_eula_language}->select($item);
}

1;
