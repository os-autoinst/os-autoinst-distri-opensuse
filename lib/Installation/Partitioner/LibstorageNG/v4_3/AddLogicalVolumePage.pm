# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handle page to add a logical volume in Expert Partitioner
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
    $self->{rb_thin_pool}   = $self->{app}->radiobutton({id => 'thin_pool'});
    $self->{rb_thin_volume} = $self->{app}->radiobutton({id => 'thin'});
    $self->{btn_next}       = $self->{app}->button({id => 'next'});
    return $self;
}

sub enter_name {
    my ($self, $lv_name) = @_;
    return $self->{tb_lv_name}->set($lv_name);
}

sub select_type {
    my ($self, $type) = @_;
    my %types = (
        'thin-pool'   => $self->{rb_thin_pool},
        'thin-volume' => $self->{rb_thin_volume}
    );
    return $types{$type}->select();
}

sub press_next {
    my ($self) = @_;
    $self->{btn_next}->click();
}

1;
