# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in Azure using azure-cli binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use utils 'zypper_call';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);
use Data::Dumper;
use publiccloud::utils;

our $root_dir = '/root';

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();
    my $azure_repo = get_required_var('PUBLIC_CLOUD_PY_AZURE_REPO');
    my $backports_repo = get_required_var('PUBLIC_CLOUD_PY_BACKPORTS_REPO');
    my $cloud_tools_repo = get_required_var('PUBLIC_CLOUD_TOOLS_REPO');
    my @test_scripts = ("azure_lib_fn.sh");
    my @tests = split(',', get_var('PUBLIC_CLOUD_AZURE_CLI_TEST'));
    my $subid = get_var('PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID');

    #possible value for PUBLIC_CLOUD_AZURE_CLI_TEST is vn,vmss,runcmd,rbac,arm_grp,arm_sub,arm_mg,lb
    foreach my $t (@tests) {
        if ("$t" eq "vn") {
            push(@test_scripts, "azure_vn.sh");
        }
        elsif ("$t" eq "vmss") {
            push(@test_scripts, "azure_vmss.sh");
        }
        elsif ("$t" eq "runcmd") {
            push(@test_scripts, "azure_runcmd.sh");
        }
        elsif ("$t" eq "rbac") {
            push(@test_scripts, "azure_rbac.sh");
        }
        elsif ("$t" eq "arm_grp") {
            push(@test_scripts, "azure_arm_grp.sh");
        }
        elsif ("$t" eq "arm_sub") {
            push(@test_scripts, "azure_arm_sub.sh");
        }
        elsif ("$t" eq "arm_mg") {
            push(@test_scripts, "azure_arm_mg.sh");
        }
        elsif ("$t" eq "lb") {
            push(@test_scripts, "azure_lb.sh");
        }
        print "included tests" . Dumper(@test_scripts);
    }

    # If 'az' is preinstalled, we test that version
    if (script_run("which az") != 0) {
        add_suseconnect_product(get_addon_fullname('pcm'),
            (is_sle('=12-sp5') ? '12' : undef));
        add_suseconnect_product(get_addon_fullname('phub'))
          if is_sle('=12-sp5');
        assert_script_run('cat /etc/os-release');
        zypper_call('addrepo -fG ' . $azure_repo);
        zypper_call('addrepo -fG ' . $backports_repo);
        zypper_call('addrepo -fG ' . $cloud_tools_repo);
        assert_script_run(
            'sudo zypper lr -u; sudo SUSEConnect -list-extensions', 300);
        script_output('sudo zypper -n ref; sudo zypper -n up',
            2000, proceed_on_failure => 1);
        record_info('zypper ref & up');
        assert_script_run(
            'sudo zypper in -y --allow-vendor-change --force azure-cli', 4600);
        record_info('azure cli installed');
    }

    assert_script_run('az version');

    set_var 'PUBLIC_CLOUD_PROVIDER' => 'AZURE';
    my $provider = $self->provider_factory();

    my $resource_group = "oqaclirg$job_id";
    my $machine_name = "oqaclivm$job_id";

    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) +
      get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    my $created_by = "$openqa_url/t$job_id";
    my $tags = "openqa-cli-test-tag=$job_id openqa_created_by=$created_by openqa_ttl=$openqa_ttl";
    $tags .= " openqa_var_server=$openqa_url openqa_var_job_id=$job_id";
    my $location = "southeastasia";
    my $sshkey = "~/.ssh/id_rsa.pub";

    # Configure default location and create Resource group
    assert_script_run("az configure --defaults location=$location");
    assert_script_run("az group create -n $resource_group --tags '$tags'");

    # Pint - command line tool to query pint.suse.com to get the current image name
    my $image_name = script_output(
        qq/pint microsoft images --active --json | jq -r '[.images[] | select( .urn | contains("sles-15-sp4:gen2") )][0].urn'/
    );
    die("The pint query output is empty.") unless ($image_name);
    record_info("PINT", "Pint query: " . $image_name);

    # Call Virtual Network ,Run Command and Virtual Machine Scale Set Test
    load_cli_test(
        $resource_group, $location, $machine_name, $sshkey,
        $image_name, $subid, @test_scripts
    );
}

sub load_cli_test {
    my ($rg, $loc, $mn, $ssh, $img, $sub_id, @cli_tests) = @_;
    my $dep_test_name = "N/A";

    #for each test it scp the test scripts and dependency scripts and execute the test
    foreach my $test_name (@cli_tests) {
        if (
            script_output("ls $root_dir/$test_name | wc -l",
                proceed_on_failure => 1) == 0
          )
        {
            record_info('Preparing permission for cli test ', $test_name);
            assert_script_run(
                "curl "
                  . data_url("publiccloud/azure_more_cli/$test_name")
                  . " -o /$root_dir/$test_name",
                60
            );

            #assert_script_run(
            #    "scp " . "/tmp/$test_name" . " remote:" . "$root_dir/$test_name",
            #    200
            #);
            assert_script_run("chmod +x " . "$root_dir/$test_name", 60);
            $dep_test_name = "N/A";
            if ($test_name eq "azure_rbac.sh") {
                $dep_test_name = "rbac.config";
            }
            elsif ($test_name eq "azure_arm_grp.sh") {
                $dep_test_name = "azure_arm_grp_template.json";
            }
            elsif ($test_name eq "azure_arm_sub.sh") {
                $dep_test_name = "azure_arm_sub_template.json";
            }
            elsif ($test_name eq "azure_arm_mg.sh") {
                $dep_test_name = "azure_arm_mg_template.json";
            }
            if ($dep_test_name ne "N/A") {
                record_info('Preparing permission for cli test ',
                    $dep_test_name);
                assert_script_run(
                    "curl "
                      . data_url("publiccloud/azure_more_cli/$dep_test_name")
                      . " -o /$root_dir/$dep_test_name",
                    60
                );

                #assert_script_run(
                #    "scp "
                #      . "/tmp/$test_name"
                #      . " remote:"
                #      . "$root_dir/$test_name",
                #    200
                #);
                assert_script_run("chmod +x " . "$root_dir/$test_name", 60);
            }
        }
        if ($test_name ne "azure_lib_fn.sh") {
            record_info('Ready to run cli test ', $test_name);
            my $start_cmd =
              $root_dir . "/$test_name $rg $loc $mn $ssh $img $sub_id";
            print "Command to Run" . Dumper($start_cmd);
            assert_script_run("$start_cmd", 3000, proceed_on_failure => 1);
        }
    }
    return;
}

sub cleanup {
    my $job_id = get_current_job_id();
    my $resource_group = "oqaclirg$job_id";
    my $machine_name = "oqaclivm$job_id";

    assert_script_run("az group delete --resource-group $resource_group --yes",
        180);
}

sub test_flags {
    return {fatal => 0, milestone => 0, always_rollback => 1};
}

1;
