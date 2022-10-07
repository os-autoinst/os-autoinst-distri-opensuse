use strict;
use warnings;
use Test::More;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any);
use testapi 'set_var';
use qesapdeployment;
set_var('QESAP_CONFIG_FILE', 'MARLIN');

subtest '[qesap_get_inventory] upper case' => sub {
    my $inventory_path = qesap_get_inventory('NEMO');
    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/root/qe-sap-deployment/terraform/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_get_inventory] lower case' => sub {
    my $inventory_path = qesap_get_inventory('nemo');
    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/root/qe-sap-deployment/terraform/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_create_folder_tree] default' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    qesap_create_folder_tree();
    note("\n  -->  " . join("\n  -->  ", @calls));
    is $calls[0], 'mkdir -p /root/qe-sap-deployment';
};

subtest '[qesap_create_folder_tree] user specified deployment_dir' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    qesap_create_folder_tree();
    note("\n  -->  " . join("\n  -->  ", @calls));
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    is $calls[0], 'mkdir -p /DORY';
};

subtest '[qesap_get_deployment_code] from default github' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    qesap_get_deployment_code();
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok any { /git.*clone.*github.*com\/SUSE\/qe-sap-deployment.*DORY/ } @calls;
    ok 1;
};

subtest '[qesap_get_deployment_code] from a release' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAPDEPLOY_VER', 'CORAL');
    qesap_get_deployment_code();
    note("\n  -->  " . join("\n  -->  ", @calls));
    set_var('QESAPDEPLOY_VER', undef);
    ok any { /curl.*github.com\/SUSE\/qe-sap-deployment\/archive\/refs\/tags\/vCORAL\.tar\.gz.*-ovCORAL\.tar\.gz/ } @calls;
    ok any { /tar.*[xvf]+.*vCORAL\.tar\.gz/ } @calls;
};


done_testing;
