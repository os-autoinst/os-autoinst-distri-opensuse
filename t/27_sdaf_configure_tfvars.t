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
      SDAF_IMAGE_PUBLISHER
      SDAF_IMAGE_OFFER
      SDAF_IMAGE_SKU
      SDAF_IMAGE_VERSION
      SDAF_IMAGE_OS_TYPE
      SDAF_SOURCE_IMAGE_ID
      SDAF_IMAGE_TYPE
    );
}

subtest '[prepare_tfvars_file] Test missing or incorrect args' => sub {
    my @incorrect_deployment_types = qw(funny_library eployer sap_ workload _zone);
    my @components = ('db_install');
    dies_ok { prepare_tfvars_file(components => \@components); } 'Fail without specifying "$deployment_type"';
    dies_ok { prepare_tfvars_file(deployment_type => $_); } "Fail with incorrect deployment type: $_" foreach @incorrect_deployment_types;
};

subtest '[prepare_tfvars_file] Test curl commands' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_tfvars', no_auto => 1);
    my $curl_cmd;
    $ms_sdaf->redefine(assert_script_run => sub { $curl_cmd = $_[0] if grep(/curl/, $_[0]); return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return $_[0]; });
    $ms_sdaf->redefine(set_image_parameters => sub { return; });
    $ms_sdaf->redefine(set_workload_vnet_name => sub { return 'vnet'; });
    $ms_sdaf->redefine(set_hana_db_parameters => sub { return 'lungo'; });
    $ms_sdaf->redefine(set_netweaver_parameters => sub { return 'americano'; });
    $ms_sdaf->redefine(data_url => sub { return 'http://openqa.suse.de/data/' . join('', @_); });

    my @components = ('db_install');
    # '-o' is only for checking if correct parameter gets picked from %tfvars_os_variable
    my %expected_results = (
        deployer => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/DEPLOYER.tfvars -o deployer_parameter_file',
        sap_system => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/SAP_SYSTEM.tfvars -o sap_system_parameter_file',
        workload_zone => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/WORKLOAD_ZONE.tfvars -o workload_zone_parameter_file',
        library => 'curl -v -fL http://openqa.suse.de/data/sles4sap/sap_deployment_automation_framework/LIBRARY.tfvars -o library_parameter_file'
    );

    for my $type (keys %expected_results) {
        prepare_tfvars_file(deployment_type => $type, components => \@components);
        is $curl_cmd, $expected_results{$type}, "Return correct url and tfvars variable";
    }
};

subtest '[set_image_parameters]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_tfvars', no_auto => 1);
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(set_workload_vnet_name => sub { return 'latte'; });
    $ms_sdaf->redefine(set_hana_db_parameters => sub { return 'lungo'; });
    $ms_sdaf->redefine(set_netweaver_parameters => sub { return 'americano'; });
    $ms_sdaf->redefine(data_url => sub { return 'capuccino'; });
    $ms_sdaf->redefine(validate_components => sub { return 'mocha'; });

    set_var('PUBLIC_CLOUD_IMAGE_LOCATION', '');
    set_var('SDAF_SOURCE_IMAGE_ID', '');
    set_var('PUBLIC_CLOUD_IMAGE_ID', 'suse:sles-sap-15-sp6:gen2:latest');
    prepare_tfvars_file(deployment_type => 'sap_system');

    my %expected_values = (
        SDAF_IMAGE_OS_TYPE => 'LINUX',
        SDAF_SOURCE_IMAGE_ID => '',
        SDAF_IMAGE_TYPE => 'marketplace',
        SDAF_IMAGE_PUBLISHER => 'suse',
        SDAF_IMAGE_OFFER => 'sles-sap-15-sp6',
        SDAF_IMAGE_SKU => 'gen2',
        SDAF_IMAGE_VERSION => 'latest'
    );

    foreach (keys(%expected_values)) {
        is get_var($_), $expected_values{$_}, "Set openQA parameter '$_' to '$expected_values{$_}'";
    }

    undef_variables;
};

subtest '[set_hana_db_parameters]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_tfvars', no_auto => 1);
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(set_workload_vnet_name => sub { return 'latte'; });
    $ms_sdaf->redefine(set_image_parameters => sub { return 'lungo'; });
    $ms_sdaf->redefine(set_netweaver_parameters => sub { return 'americano'; });
    $ms_sdaf->redefine(data_url => sub { return 'capuccino'; });

    prepare_tfvars_file(deployment_type => 'sap_system', components => ['db_install', 'db_ha']);
    is get_var('SDAF_HANA_HA_SETUP'), 'true', 'Set "SDAF_HANA_HA_SETUP" to true with "db_ha" scenario';

    prepare_tfvars_file(deployment_type => 'sap_system', components => ['db_install']);
    is get_var('SDAF_HANA_HA_SETUP'), 'false', 'Set "SDAF_HANA_HA_SETUP" to false for non HA scenario';
    undef_variables;
};

subtest '[set_netweaver_parameters] Scenario "nw_pas,nw_aas,nw_ensa"' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_tfvars', no_auto => 1);
    $ms_sdaf->redefine(assert_script_run => sub { return 1; });
    $ms_sdaf->redefine(upload_logs => sub { return 1; });
    $ms_sdaf->redefine(replace_tfvars_variables => sub { return 1; });
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(set_workload_vnet_name => sub { return 'latte'; });
    $ms_sdaf->redefine(set_image_parameters => sub { return 'lungo'; });
    $ms_sdaf->redefine(data_url => sub { return 'capuccino'; });

    prepare_tfvars_file(deployment_type => 'sap_system',
        components => ['nw_pas', 'nw_aas', 'nw_ensa']);

    is get_var('SDAF_ASCS_SERVER'), '1', 'Set "SDAF_ASCS_SERVER" to "1"';
    is get_var('SDAF_APP_SERVER_COUNT'), '2', 'Set "SDAF_APP_SERVER_COUNT" to "2"';
    is get_var('SDAF_ERS_SERVER'), 'true', 'Set "SDAF_ERS_SERVER" to "true"';

    undef_variables;
};

subtest '[validate_components]' => sub {
    ok validate_components(components => ['db_install']), "Pass with 'db_install' argument";
    ok validate_components(components => ['db_ha']), "Pass with 'db_ha' argument";
    ok validate_components(components => ['nw_pas']), "Pass with 'nw_pas' argument";
    ok validate_components(components => ['nw_aas']), "Pass with 'nw_aas' argument";
    ok validate_components(components => ['nw_ensa']), "Pass with 'nw_ensa' argument";
};

subtest '[validate_components] Exceptions' => sub {
    my @incorrect_values = ('db', 'pas', 'nw', 'ensa', 'aas', 'ha');

    foreach (@incorrect_values) {
        dies_ok { validate_components(components => [$_]) } "Fail with unsupported value: '$_'";
    }

};

done_testing;

