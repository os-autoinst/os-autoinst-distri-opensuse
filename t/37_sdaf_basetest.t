use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::basetest;
use Data::Dumper;

subtest '[sdaf_ibsm_teardown] ' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::basetest', no_auto => 1);

    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $ms_sdaf->redefine(find_deployment_id => sub { return '123'; });
    $ms_sdaf->redefine(az_network_vnet_get => sub {
            return ['ibsm_vnet'] if grep(/ibsm/, @_); return ['workload_vnet'] });
    $ms_sdaf->redefine(get_ibsm_peering_name => sub {
        return 'ibsm_peering' if {@_}->{target_vnet} eq 'ibsm_vnet';
        return 'workload_peering', });
    $ms_sdaf->redefine(az_group_name_get => sub { return ['workload']; });
    $ms_sdaf->redefine(az_network_peering_delete => sub { return shift(); });

    set_var('IBSM_RG', 'ibsm_resource_group');
    my $report = sdaf_ibsm_teardown();
    print Dumper($report);
};

subtest '[sdaf_ibsm_teardown] ' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::basetest', no_auto => 1);
    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

};

1;
