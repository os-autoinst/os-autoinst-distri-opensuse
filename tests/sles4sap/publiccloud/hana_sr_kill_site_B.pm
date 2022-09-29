
use strict;
use warnings FATAL => 'all';
use diagnostics;
use Data::Dumper;
use testapi;
use base 'publiccloud::basetest';;
use Mojo::JSON;
use Mojo::File qw(path);
use sles4sap_publiccloud;
use publiccloud::utils;

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    my $site_b = $run_args->{site_b};

    $self->select_serial_terminal;

    # Switch to control Site B (currently PROMOTED)
    $self->{my_instance} = $site_b;

    record_info("Stop DB", "Running 'HDB -kill' on Site B ('$site_b->{instance_id}')");
    $self->stop_hana(method => "kill");

    record_info("Takeover check");
    $self->check_takeover;

    record_info("Replication", "Enabling replication on Site B (DEMOTED)");
    $self->enable_replication();

    record_info("Site B start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");
}

1;