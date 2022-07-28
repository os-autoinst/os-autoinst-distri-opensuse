# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for existing instance connection
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::existing;
use Mojo::Base -base;
use testapi;
use publiccloud::utils;

has username => undef;
has public_ip => undef;
has ssh_key => undef;

sub init {
    my ($self, %params) = @_;
}

1;
