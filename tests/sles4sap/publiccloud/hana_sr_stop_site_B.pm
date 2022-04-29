
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
    my ($self, $run_args) = @_;
    my $site_b = $run_args->{site_b};

    $self->select_serial_terminal;

    # Switch to control Site B
    $self->{my_instance} = $site_b;

    record_info("Stop DB", "Stopping Site B ('$site_b->{instance_id}')");
    $self->stop_hana();

    record_info("Takeover check");
    $self->check_takeover;

    record_info("Replication", "Enabling replication on Site B");
    $self->enable_replication();

    record_info("Site B start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");

}

1;