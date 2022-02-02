
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
use Storable;


sub run {
    my ($self, $run_args) = @_;
    my $instances_import_path = get_var("INSTANCES_IMPORT");
    my $instances;

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    if (defined($instances_import_path) and length($instances_import_path)) {
        $instances = retrieve($instances_import_path);
    }
    else {
        $instances = $run_args->{instances};
    }

    $self->select_serial_terminal;

    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        my $instance_id = $instance->{'instance_id'};
        die("test");
        # Skip instances without HANA db
        next if ($instance_id !~ m/vmhana/);

        # Skip if node is not Master
        next if ($self->is_hana_master(hostname => $instance_id) eq 1);
        record_info("Master node:", "Current master node: $instance_id");

        record_info('Stop HANA', "Stopping HANA database on Master node");
        #$self->stop_hana();
        my $takeover_result = $self->do_takeover();
        record_info('HANA status', $takeover_result);
    }
}

1;