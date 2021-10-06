# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Logger;
use strict;
use warnings;
use Term::ANSIColor;

my $instance;

sub get_instance {
    my ($class, $args) = @_;

    return $instance if defined $instance;
    $instance = bless {
        logger => Mojo::Log->new(
            level  => $args->{level},
            format => $args->{format},
            path   => $args->{path})
    }, $class;
}

sub debug {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('white'));
    $instance->{logger}->debug($message)->append(color('reset'));
}

sub info {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('blue'));
    $instance->{logger}->info($message)->append(color('reset'));
}

sub warn {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('yellow'));
    $instance->{logger}->warn($message)->append(color('reset'));
}

sub error {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('bold red'));
    $instance->{logger}->error($message)->append(color('reset'));
}

sub fatal {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('bold red'));
    $instance->{logger}->fatal($message)->append(color('reset'));
}

1;
