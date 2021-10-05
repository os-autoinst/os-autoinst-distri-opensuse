# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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
