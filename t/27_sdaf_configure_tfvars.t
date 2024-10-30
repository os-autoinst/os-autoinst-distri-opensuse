use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::configure_tfvars;

sub undef_variables {
    # undefines OpenQA variables
    set_var($_, undef) foreach qw(
      SDAF_DB_IMAGE_PUBLISHER
      SDAF_DB_IMAGE_OFFER
      SDAF_DB_IMAGE_SKU
      SDAF_DB_IMAGE_VERSION
      SDAF_DB_IMAGE_OS_TYPE
      SDAF_DB_SOURCE_IMAGE_ID
      SDAF_DB_IMAGE_TYPE
    );
}

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
    $ms_sdaf->redefine(set_db_image_parameters => sub { return; });
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

subtest '[set_vm_image_parameters]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_tfvars', no_auto => 1);
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(set_workload_vnet_name => sub { return 'latte'; });
    $ms_sdaf->redefine(data_url => sub { return 'capuccino'; });

    set_var('PUBLIC_CLOUD_IMAGE_ID', 'suse:sles-sap-15-sp6:gen2:latest');
    prepare_tfvars_file(deployment_type => 'sap_system');

    my %expected_values = (
        SDAF_DB_IMAGE_OS_TYPE => 'LINUX',
        SDAF_DB_SOURCE_IMAGE_ID => '',
        SDAF_DB_IMAGE_TYPE => 'marketplace',
        SDAF_DB_IMAGE_PUBLISHER => 'suse',
        SDAF_DB_IMAGE_OFFER => 'sles-sap-15-sp6',
        SDAF_DB_IMAGE_SKU => 'gen2',
        SDAF_DB_IMAGE_VERSION => 'latest'
    );

    foreach (keys(%expected_values)) {
        is get_var($_), $expected_values{$_}, "Set openQA parameter '$_' to '$expected_values{$_}'";
    }

    undef_variables;
};

done_testing;

