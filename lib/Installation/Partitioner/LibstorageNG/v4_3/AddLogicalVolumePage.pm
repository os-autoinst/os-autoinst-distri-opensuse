# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods to handle addition of logical
# volumes in Expert Partitioner.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::AddLogicalVolumePage;
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

    $self->{tb_lv_name}     = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::LvmLvInfo::NameWidget"'});
    $self->{rb_system}      = $self->{app}->radiobutton({id => 'system'});
    $self->{rb_swap}        = $self->{app}->radiobutton({id => 'swap'});
    $self->{tb_size}        = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::LvmLvSize::CustomSizeInput"'});
    $self->{rb_custom_size} = $self->{app}->radiobutton({id => 'custom_size'});
    $self->{btn_next}       = $self->{app}->button({id => 'next'});
    $self->{rb_thin_pool}   = $self->{app}->radiobutton({id => 'thin_pool'});
    $self->{rb_thin_volume} = $self->{app}->radiobutton({id => 'thin'});
    return $self;
}

sub set_logical_volume_name {
    my ($self, $lv_name) = @_;
    return $self->{tb_lv_name}->set($lv_name);
}

sub set_custom_size {
    my ($self, $size) = @_;
    $self->{rb_custom_size}->select();
    return $self->{tb_size}->set($size);
}

sub select_role {
    my ($self, $role) = @_;
    $role //= '';
    if ($role eq 'operating-system') {
        $self->{rb_system}->select();
    }
    elsif ($role eq 'swap') {
        $self->{rb_swap}->select();
    }
}

sub press_next_button {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

sub set_logical_volume_type {
    my ($self, $type) = @_;
    if ($type eq 'thin_pool') {
        $self->{rb_thin_pool}->select();
    } elsif ($type eq 'thin_volume') {
        $self->{rb_thin_volume}->select();
    }
}

1;
