# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces methods to handle Partitioning Scheme page.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::PartitioningSchemePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{chb_enable_lvm} = $self->{app}->checkbox({id => 'lvm'});
    $self->{chb_enable_disk_encryption} = $self->{app}->checkbox({id => 'encryption'});
    $self->{txb_password} = $self->{app}->textbox({id => 'password'});
    $self->{txb_repeat_password} = $self->{app}->textbox({id => 'repeat_password'});
    return $self;
}

sub select_enable_lvm {
    my ($self) = @_;
    $self->{chb_enable_lvm}->check();
}

sub unselect_enable_lvm {
    my ($self) = @_;
    $self->{chb_enable_lvm}->uncheck();
}

sub select_enable_disk_encryption {
    my ($self) = @_;
    $self->{chb_enable_disk_encryption}->check();
}

sub enter_password {
    my ($self, $password) = @_;
    return $self->{txb_password}->set($password);
}

sub enter_confirm_password {
    my ($self, $password) = @_;
    return $self->{txb_repeat_password}->set($password);
}

sub is_shown {
    my ($self) = @_;
    return $self->{chb_enable_lvm}->exist();
}

1;
