use strict;
use warnings;
use Test::More;
use Test::Warnings;

use qesapdeployment;

subtest '[qesap_get_inventory] upper case' => sub {
    use testapi 'set_var';
    set_var('QESAP_CONFIG_FILE', 'MARLIN');
    my $inventory_path = qesap_get_inventory('NEMO');
    note('inventory_path --> ' . $inventory_path);
    ok $inventory_path eq '/root/qe-sap-deployment/terraform/nemo/inventory.yaml';
};

subtest '[qesap_get_inventory] lower case' => sub {
    use testapi 'set_var';
    set_var('QESAP_CONFIG_FILE', 'MARLIN');
    my $inventory_path = qesap_get_inventory('nemo');
    note('inventory_path --> ' . $inventory_path);
    ok $inventory_path eq '/root/qe-sap-deployment/terraform/nemo/inventory.yaml';
};

done_testing;
