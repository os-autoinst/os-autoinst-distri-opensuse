# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test will leave the SSH interactive session, kill the SSH tunnel and destroy the public cloud instance
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive;
use publiccloud::utils;
use testapi;
use utils;

sub run {
    my ($self, $args) = @_;
    select_host_console(force => 1);
    $args->{my_provider}->cleanup();
}

1;

