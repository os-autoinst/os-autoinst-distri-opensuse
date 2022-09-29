package hana_sr_destroy_all;

use parent 'Exporter';
use strict;
use warnings FATAL => 'all';
use Mojo::Base 'publiccloud::basetest';
use qesapdeployment;
use testapi;

sub test_flags {
    return {
        fatal => 1
    };
}

sub run {
    if (get_var('INSTANCES_IMPORT') or get_var('INSTANCES_EXPORT')) {
        record_info("No cleanup", "Cleanup skipped - 'INSTANCE_IMPORT' or 'INSTANCE_EXPORT' variable defined");
        return;
    }
    qesap_execute(verbose=>"--verbose", cmd=>"terraform", cmd_options=>"-d", timeout=>600);
}

1;