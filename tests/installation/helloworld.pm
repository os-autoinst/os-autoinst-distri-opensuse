# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module is a simple hello world program for 
# testing the workflow of openqa.

# Maintainer: Sudarshan Mhalas <sudarshan.mhalas@suse.com>

package helloworld;

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub run {
    my ($self) = @_;
    
    if (get_var('HW')) {
        # Print a greeting message
        record_info("Hello World", "********** Hello World! **********");
    } else {
        record_info("Hello World", "Hello World message skipped");
    }
}

sub test_flags {
    return { fatal => 1 };
}

1;