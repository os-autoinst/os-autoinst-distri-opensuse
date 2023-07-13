# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles encryption of a partition using Expert Partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::EncryptPartitionPage;
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
    my $self = shift;
    $self->SUPER::init();
    $self->{txb_pass} = $self->{app}->textbox({id => 'pw1'});
    $self->{txb_pass_reenter} = $self->{app}->textbox({id => 'pw2'});
    return $self;
}

sub set_encryption {
    my ($self) = @_;
    $self->enter_password($testapi::password);
    $self->reenter_password($testapi::password);
    $self->press_next();
}

sub enter_password {
    my ($self, $password) = @_;
    return $self->{txb_pass}->set($password);
}

sub reenter_password {
    my ($self, $password) = @_;
    return $self->{txb_pass_reenter}->set($password);
}

1;
