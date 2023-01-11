# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Kernel Parameters tab
# in Boot Loader Settings.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Bootloader::KernelParametersPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{txb_opt_kernel_param} = $self->{app}->textbox({id => "\"Bootloader::KernelAppendWidget\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{txb_opt_kernel_param}->exist();
}

sub get_optional_kernel_param {
    my ($self) = @_;
    $self->{txb_opt_kernel_param}->value();
}

sub set_optional_kernel_param {
    my ($self, $param) = @_;
    $self->{txb_opt_kernel_param}->set($param);
}

1;
