# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act on System Role page in
#          the installer.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::SystemRole::Sle::SystemRolePage;
use parent Installation::SystemRole::SystemRolePage;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{role_GNOME_desktop}        = 'SLES with GNOME';
    $self->{role_text_mode}            = 'Text Mode';
    $self->{role_minimal}              = 'Minimal';
    $self->{role_transactional_server} = 'Transactional Server';
    $self->{role_HA_node}              = 'HA node';
    return $self;
}

1;
