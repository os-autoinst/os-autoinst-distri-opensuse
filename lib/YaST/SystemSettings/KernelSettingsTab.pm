# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for YaST module
# Kernel Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::SystemSettings::KernelSettingsTab;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{cb_sysrq} = $self->{app}->checkbox({id => '"sysrq"'});
    return $self;
}

sub uncheck_sysrq {
    my ($self) = @_;
    $self->{cb_sysrq}->uncheck();
}

sub check_sysrq {
    my ($self) = @_;
    $self->{cb_sysrq}->check();
}

1;
