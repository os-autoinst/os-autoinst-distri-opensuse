# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Performing Installation
#          Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::PerformingInstallation::PerformingInstallationPage;
use strict;
use warnings;
use YuiRestClient::Wait;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{pba_total_packages} = $self->{app}->progressbar({id => 'progressTotal'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{pba_total_packages}->exist();
}

sub wait_finished {
    my ($self, $timeout) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            return !($self->is_shown());
          }, timeout => $timeout, interval => 10, message => "Progress bar displaying total installing packages didn't disappear. " .
          "Installation got stuck or took more time than $timeout seconds.");
}

1;
