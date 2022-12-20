# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the
#          Import SSH Host Keys ad Configuration page
#          of the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::SSHKeyImport::SSHKeyImportController;
use strict;
use warnings;
use Installation::SSHKeyImport::SSHKeyImportPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SSHImportPage} = Installation::SSHKeyImport::SSHKeyImportPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_ssh_import_page {
    my ($self) = @_;
    die "Import SSH Host Keys and Configuration page is not displayed" unless $self->{SSHImportPage}->is_shown();
    return $self->{SSHImportPage};
}

sub enable_ssh_import {
    my ($self) = @_;
    return $self->get_ssh_import_page()->enable_ssh_import();
}

sub disable_ssh_import {
    my ($self) = @_;
    return $self->get_ssh_import_page()->disable_ssh_import();
}

sub accept {
    my ($self) = @_;
    return $self->get_ssh_import_page()->press_accept();
}

1;
