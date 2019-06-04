# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle root user password entry
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use parent qw(installation_user_settings y2_installbase);
use testapi;

sub run {
    my ($self) = @_;
    $self->enter_rootinfo;
}

1;
