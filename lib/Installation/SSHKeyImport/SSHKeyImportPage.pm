# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the
#          Import SSH Host Keys and Configuration page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::SSHKeyImport::SSHKeyImportPage;
use strict;
use warnings;
use YuiRestClient::Wait;
use testapi 'save_screenshot';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{chb_import} = $self->{app}->checkbox({id => 'import_ssh_key'});
    $self->{chb_copy_config} = $self->{app}->checkbox({id => 'copy_config'});
    $self->{btn_accept} = $self->{app}->button({id => 'accept'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{chb_import}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub enable_ssh_import {
    my ($self) = @_;
    return $self->{chb_import}->check();
}

sub disable_ssh_import {
    my ($self) = @_;
    return $self->{chb_import}->uncheck();
}

sub press_accept {
    my ($self) = @_;
    return $self->{btn_accept}->click();
}

1;
