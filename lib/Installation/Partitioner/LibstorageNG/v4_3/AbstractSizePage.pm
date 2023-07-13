# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Expert Partitioner Page to handles shared functionality
# for partition size. Classes implementing it will provide a new() method
# and its own textbox for 'tb_size' which is different depending on the type
# of partitioning.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::AbstractSizePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;
use YuiRestClient::Wait;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{rdb_custom_size} = $self->{app}->radiobutton({id => 'custom_size'});
    return $self;
}

sub set_custom_size {
    my ($self, $size) = @_;
    if ($size) {
        YuiRestClient::Wait::wait_until(object => sub {
                return $self->{rdb_custom_size}->is_enabled();
        }, message => "Custom size radio button takes too long to be enabled");
        $self->{rdb_custom_size}->select();
        $self->{txb_size}->set($size);
    }
    $self->press_next();
}

1;
