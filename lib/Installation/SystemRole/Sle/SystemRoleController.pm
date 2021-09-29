# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for System Role Page
#          in the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::SystemRole::Sle::SystemRoleController;
use parent 'Installation::SystemRole::SystemRoleController';
use strict;
use warnings;
use Installation::SystemRole::Sle::SystemRolePage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{SystemRolePage} = Installation::SystemRole::Sle::SystemRolePage->new({app => YuiRestClient::get_app()});
    return $self;
}

1;
