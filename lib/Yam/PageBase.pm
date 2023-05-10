# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Page base
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::PageBase;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    $args->{app} = YuiRestClient::get_app();
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init ();

1;
