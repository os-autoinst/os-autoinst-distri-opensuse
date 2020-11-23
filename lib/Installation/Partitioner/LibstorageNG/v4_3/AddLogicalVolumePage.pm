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

    $self->{tb_lv_name} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::LvmLvInfo::NameWidget"'});
    $self->{rb_system}  = $self->{app}->radiobutton({id => 'system'});
    $self->{rb_swap}    = $self->{app}->radiobutton({id => 'swap'});
    $self->{btn_next}   = $self->{app}->button({id => 'next'});

    return $self;
}

sub set_logical_volume_name {
    my ($self, $lv_name) = @_;
    return $self->{tb_lv_name}->set($lv_name);
}

sub select_role {
    my ($self, $role) = @_;
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

1;
