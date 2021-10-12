# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles Authentication for the System Administrator "root" page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AuthenticationForRoot::AuthenticationForRootPage;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{lbl_import_public_ssh_key} = $self->{app}->label({label => 'Import Public SSH Key'});
    $self->{tb_confirm_password} = $self->{app}->textbox({id => 'pw2'});
    $self->{tb_password} = $self->{app}->textbox({id => 'pw1'});
    return $self;
}

sub enter_password {
    my ($self, $password) = @_;
    return $self->{tb_password}->set($password);
}

sub enter_confirm_password {
    my ($self, $password) = @_;
    return $self->{tb_confirm_password}->set($password);
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_import_public_ssh_key}->exist();
}

1;
