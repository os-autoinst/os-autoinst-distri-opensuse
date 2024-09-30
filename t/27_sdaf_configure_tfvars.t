use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::configure_tfvars;

subtest '[prepare_tfvars_file] Test missing or incorrect args' => sub {
    my @incorrect_deployment_types = qw(funny_library eployer sap_ workload _zone);
    dies_ok { prepare_tfvars_file(); } 'Fail without specifying "$deployment_type"';
    dies_ok { prepare_tfvars_file(deployment_type => $_); } "Fail with incorrect deployment type: $_" foreach @incorrect_deployment_types;
};

subtest '[prepare_tfvars_file] Test curl commands' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_tfvars', no_auto => 1);
    my $curl_cmd;
    $ms_sdaf->redefine(assert_script_run => sub { $curl_cmd = $_[0] if grep(/curl/, $_[0]); return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return $_[0]; });
    $ms_sdaf->redefine(set_workload_vnet_name => sub { return 'vnet'; });

    $ms_sdaf->redefine(data_url => sub { return 'http://openqa.suse.de/data/' . join('', @_); });

    # '-o' is only for checking if correct parameter gets picked from %tfvars_os_variable
    my %expected_results = (
        deployer => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/DEPLOYER.tfvars -o deployer_parameter_file',
        sap_system => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/SAP_SYSTEM.tfvars -o sap_system_parameter_file',
        workload_zone => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/WORKLOAD_ZONE.tfvars -o workload_zone_parameter_file',
        library => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/LIBRARY.tfvars -o library_parameter_file'
    );

    for my $type (keys %expected_results) {
        prepare_tfvars_file(deployment_type => $type);
        is $curl_cmd, $expected_results{$type}, "Return correct url and tfvars variable";
    }
};

done_testing;

