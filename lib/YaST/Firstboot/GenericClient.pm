# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

package YaST::Firstboot::GenericClient;
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
    my ($self, $debug_label) = @_;
    $self->{btn_next}           = $self->{app}->button({id => 'next'});
    $self->{client_debug_label} = $self->{app}->debug_label({'debug_label' => $debug_label});
    return $self;
}

# sub text {
#     my ($self) = @_;
#     return $self->{client_debug_label}->text();
# }

# sub confirm_text {
#     my ($self, $expected) = @_;
#     my $text = $self->text();
#     # ensure correct text
#     if ($text !~ $expected) {
#         die "Unexpected debug label found:\n" .
#           "text: $text\nregex:$expected";
#     }
# }

sub assert_client {
    my ($self, $args) = @_;
    # $self->confirm_text($args);
    return $self->{client_debug_label}->exist($args);
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}


1;
