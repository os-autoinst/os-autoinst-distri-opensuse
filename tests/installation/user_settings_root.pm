# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle root user password entry
# - Fill password field (and password confirmation) during install procedure
# Maintainer: Stephan Kulow <coolo@suse.de>

use parent qw(installation_user_settings y2_installbase);
use testapi;

sub run {
    my ($self) = @_;
    $self->enter_rootinfo;
}

1;
