
use strict;
use warnings FATAL => 'all';
use diagnostics;
use Data::Dumper;
use testapi;
use Mojo::Base qw(publiccloud::basetest);
use Mojo::JSON;
use Mojo::File qw(path);
use sles4sap_publiccloud;
use publiccloud::utils;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;
    $self->identify_instances();

    # Switch to control Site A
    $self->{my_instance} = $self->{site_a};
    #$self->stop_hana();
    #$self->check_takeover;
    $self->enable_replication();


    record_info("Good");
}

1;