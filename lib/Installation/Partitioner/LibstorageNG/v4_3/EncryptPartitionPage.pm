# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles encryption of a partition using Expert Partitioner.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::EncryptPartitionPage;
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
    $self->{tb_pass}         = $self->{app}->textbox({id => 'pw1'});
    $self->{tb_pass_reenter} = $self->{app}->textbox({id => 'pw2'});
    $self->{btn_next}        = $self->{app}->button({id => 'next'});
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
    return $self->{tb_pass}->set($password);
}

sub reenter_password {
    my ($self, $password) = @_;
    return $self->{tb_pass_reenter}->set($password);
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
