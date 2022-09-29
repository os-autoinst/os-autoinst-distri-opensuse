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

sub run {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    my $hana_start_timeout = bmwqemu::scale_timeout(600);
    my $site_b = $run_args->{site_b};
    $self->select_serial_terminal;

    # Switch to control Site B (currently replica mode)
    $self->{my_instance} = $site_b;

    my $cluster_status = $self->run_cmd(cmd=>"crm status");
    record_info( "Cluster status", $cluster_status );
    # Check initial state: 'site B' = replica mode
    die("Site B '$site_b->{instance_id}' is NOT in replication mode.") if
        $self->get_promoted_hostname() eq $site_b->{instance_id};

    # Stop DB
    record_info("Stop DB", "Stopping Site B ('$site_b->{instance_id}')");
    $self->stop_hana(method => "stop");

    # wait for DB to start with resources
    $self->is_hana_online(wait_for_start => 'true');
    my $hana_started = time;
    while ( time - $hana_started > $hana_start_timeout ) {
        last if $self->is_hana_resource_running();
        sleep 30;
    }


    # Check if DB started as primary
    die("Site B '$site_b->{instance_id}' did NOT start in replication mode.")
        if $self->get_promoted_hostname() eq $site_b->{instance_id};

    record_info("Done", "Test finished");
}

sub test_flags {
    return {fatal => 1};
}

1;