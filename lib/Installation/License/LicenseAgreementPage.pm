# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Page to handle License Agreement page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::License::LicenseAgreementPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{cmb_language} = $self->{app}->combobox($args->{cmb_language_filter});
    $self->{rct_eula} = $self->{app}->richtext($args->{rct_eula_filter});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rct_eula}->exist();
}

sub get_available_languages {
    my ($self) = @_;
    return $self->{cmb_language}->items();
}

sub get_eula_content {
    my ($self) = @_;
    return $self->{rct_eula}->text();
}

sub get_selected_language {
    my ($self) = @_;
    return $self->{cmb_language}->value();
}

sub select_language {
    my ($self, $item) = @_;
    return $self->{cmb_language}->select($item);
}

1;
