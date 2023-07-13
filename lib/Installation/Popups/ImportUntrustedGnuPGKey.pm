# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to handle
# a Trust&Import popup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::ImportUntrustedGnuPGKey;
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
    $self->{btn_trust} = $self->{app}->button({id => 'trust'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{btn_trust}->exist();
}

sub press_trust {
    my ($self) = @_;
    $self->{btn_trust}->click();
}

1;
