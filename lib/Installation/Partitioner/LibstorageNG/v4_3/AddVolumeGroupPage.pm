# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods to operate add volume group page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::AddVolumeGroupPage;
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

    $self->{btn_next}              = $self->{app}->button({id => 'next'});
    $self->{btn_add}               = $self->{app}->button({id => 'add'});
    $self->{btn_add_all}           = $self->{app}->button({id => 'add_all'});
    $self->{txtbox_vg_name}        = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::LvmVg::NameWidget"'});
    $self->{tbl_available_devices} = $self->{app}->table({id => '"unselected"'});
    $self->{tbl_selected_devices}  = $self->{app}->table({id => '"selected"'});

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

sub press_next_button {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

sub select_available_device {
    my ($self, $device) = @_;
    return $self->{tbl_available_devices}->select(value => $device);
}

sub set_volume_group_name {
    my ($self, $vg_name) = @_;
    return $self->{txtbox_vg_name}->set($vg_name);
}

1;
