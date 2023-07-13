# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to operate add volume group page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::AddVolumeGroupPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

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
    $self->{btn_add} = $self->{app}->button({id => 'add'});
    $self->{btn_add_all} = $self->{app}->button({id => 'add_all'});
    $self->{txb_vg_name} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::LvmVg::NameWidget"'});
    $self->{tbl_available_devices} = $self->{app}->table({id => '"unselected"'});
    $self->{tbl_selected_devices} = $self->{app}->table({id => '"selected"'});

    return $self;
}

sub press_add_all_button {
    my ($self) = @_;
    return $self->{btn_add_all}->click();
}

sub press_add_button {
    my ($self) = @_;
    return $self->{btn_add}->click();
}

sub select_available_device {
    my ($self, $device) = @_;
    return $self->{tbl_available_devices}->select(value => $device);
}

sub set_volume_group_name {
    my ($self, $vg_name) = @_;
    $self->{txb_vg_name}->exist();
    return $self->{txb_vg_name}->set($vg_name);
}

1;
