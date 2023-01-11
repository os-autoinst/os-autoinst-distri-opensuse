# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle page to add a logical volume in Expert Partitioner
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::AddLogicalVolumePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;
use testapi;

use YuiRestClient;

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
    $self->{txb_lv_name} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::LvmLvInfo::NameWidget"'});
    $self->{rdb_thin_pool} = $self->{app}->radiobutton({id => 'thin_pool'});
    $self->{rdb_thin_volume} = $self->{app}->radiobutton({id => 'thin'});
    return $self;
}

sub enter_name {
    my ($self, $lv_name) = @_;
    return $self->{txb_lv_name}->set($lv_name);
}

sub select_type {
    my ($self, $type) = @_;
    my %types = (
        'thin-pool' => $self->{rdb_thin_pool},
        'thin-volume' => $self->{rdb_thin_volume}
    );
    return $types{$type}->select();
}

1;
