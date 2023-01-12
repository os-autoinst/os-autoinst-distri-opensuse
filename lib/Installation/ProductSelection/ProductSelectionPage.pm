# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Product Selection page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::ProductSelection::ProductSelectionPage;
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
    $self->{rdb_SLES} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise Server 15/});
    $self->{rdb_HPC} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise High Performance Computing 15/});
    $self->{rdb_SLES_for_SAP} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise Server for SAP Applications 15/});
    $self->{rdb_SLED} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise Desktop 15/});
    $self->{rdb_SMGR_Server} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Manager Server/});
    $self->{rdb_SMGR_Proxy} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Manager Proxy/});
    $self->{rdb_SMGR_Retail} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Manager Retail Branch Server/});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rdb_SLES}->exist({timeout => 300, interval => 10});
}

sub install_product {
    my ($self, $product) = @_;
    $self->{"rdb_$product"}->select();
}

1;
