# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Slurm master node
#    This test is setting up slurm master node and runs tests depending
#    on the slurm cluster configuration
# Maintainer: Sebastian Chlad <sebastian.chlad@suse.com>

use base 'hpcbase';
use base 'hpc::configs';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use Data::Dumper;
use Mojo::JSON;

## TODO: provide better parser for HPC specific tests
sub validate_result {
    my ($result) = @_;

    if ($result == 0) {
        return 'PASS';
    } elsif ($result == 1) {
        return 'FAIL';
    } else {
        return undef;
    }
}

sub generate_results {
    my ($name, $description, $result) = @_;

    my %results = (
        test        => $name,
        description => $description,
        result      => validate_result($result)
    );
    return %results;
}

sub pars_results {
    my (%test) = @_;
    my $file = 'tmpresults.xml';

    my $test_name   = $test{test};
    my $description = $test{description};
    my $result      = $test{result};

    if ($result eq 'FAIL') {
        script_run("echo \"<testcase name='$test_name' errors='1'>\" >>  $file");
    } else {
        script_run("echo \"<testcase name='$test_name'>\" >> $file");
    }
    script_run("echo \"<system-out>\" >> $file");
    script_run("echo $description >>  $file");
    script_run("echo \"</system-out>\" >> $file");
    script_run("echo \"</testcase>\" >> $file");
}

sub basic_test_01 {
    my $name        = 'Srun check';
    my $description = 'Basic SRUN test';

    my $result = script_run("srun -w slave-node00 date");

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub basic_test_02 {
    my $name        = 'Sinfo check';
    my $description = 'Simple SINFO test';

    my $result = script_run('sinfo');

    ##TODO: add check of sinfo vs slurm.conf?

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub basic_test_03 {
    my $name        = 'Stress tests with srun';
    my $description = 'SRUN stress test';

    ##TODO: implement srun stress test; run 100+ srun jobs
}

sub basic_test_04 {
    my $name        = 'Sbatch test';
    my $description = 'Basic SBATCH test';
    my $sbatch      = 'slurm_sbatch.sh';

    script_run("wget --quiet " . data_url("hpc/$sbatch") . " -O $sbatch");
    assert_script_run("chmod +x $sbatch");
    record_info('meminfo', script_output("cat /proc/meminfo"));
    my $result = script_output("sbatch $sbatch");
    ##sbatch SBATCH --time=0-00:01:00
    ## so the worker should wait for the sbatch to finish
    ## sbatch is publishing some files, so the test should hang
    sleep(70);
    upload_logs('/tmp/sbatch1');

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub basic_test_05 {
    my $name        = 'Slurm-torque test';
    my $description = 'Basic slurm-torque test. https://fate.suse.com/323998';
    my $pbs         = 'slurm_pbs.sh';

    script_run("wget --quiet " . data_url("hpc/$pbs") . " -O $pbs");
    assert_script_run("chmod +x $pbs");
    my $result = script_output("sbatch $pbs");
    ## execution (wall time) time set to 1m and there is a sleep
    ## in the PBS script
    ## so the worker should wait for the pbs to finish
    ## sbatch is publishing some files, so the test should hang
    sleep(80);
    upload_logs('/tmp/Job_PBS_o');
    upload_logs('/tmp/Job_PBS_e');

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub ha_test_01 {
    ##TODO: Add fail-over test
}

sub accounting_test_01 {
    my $name        = 'Slurm accounting';
    my $description = 'Basic check for slurm accounting cmd';
    my $result      = 0;
    my %users       = (
        'user_1' => 'Sebastian',
        'user_2' => 'Egbert',
        'user_3' => 'Christina',
        'user_4' => 'Jose',
    );

    ##Add users TODO: surely this should be abstracted
    script_run("useradd $users{user_1}");
    script_run("useradd $users{user_2}");
    script_run("useradd $users{user_3}");
    script_run("useradd $users{user_4}");

    script_run('sacctmgr -i add cluster linux');
    my $cluster = script_output('sacctmgr -n -p list cluster');

    if (index($cluster, 'linux') == -1) {
        #cluster not successfully added
        $result = 1;
        goto FAIL;
    }

    ### Create accounts in org=UNI_X
    script_run("sacctmgr -i add account UNI_X_IT Description=\"IT at UNI_X\" Organization=UNI_X");
    script_run("sacctmgr -i add account UNI_X_Math Description=\"Math at ORG_X\" Organization=UNI_X");
    #Add users associated with account in org=UNI_X
    script_run("sacctmgr -i create user name=$users{user_1} DefaultAccount=UNI_X_Math");
    script_run("sacctmgr -i create user name=Jose DefaultAccount=UNI_X_Math");
    script_run("sacctmgr -i create user name=$users{user_2} DefaultAccount=UNI_X_IT");
    script_run("sacctmgr -i create user name=Christian DefaultAccount=UNI_X_IT");

    ### Create accounts in org=UNI_Y
    script_run("sacctmgr -i add account UNI_Y_Physics Description=\"UNI_Y\" Organization=UNI_Y");
    script_run("sacctmgr -i add account UNI_Y_Biology Description=\"UNI_Y\" Organization=UNI_Y");
    #Add users associated with account in org=UNI_Y
    script_run("sacctmgr -i create user name=Joe DefaultAccount=UNI_Y_Physics");
    script_run("sacctmgr -i create user name=Noah DefaultAccount=UNI_Y_Biology");
    script_run("sacctmgr -i create user name=$users{user_4} DefaultAccount=UNI_Y_Physics");
    script_run("sacctmgr -i create user name=$users{user_3} DefaultAccount=UNI_Y_Biology");

    script_run('sacctmgr show account');
    script_run('sacctmgr show associations');
    record_info('INFO', script_run('sacctmgr show account'));

    script_run("srun --uid=$users{user_1} --account=UNI_X_Math -w slave-node00,slave-node01 date");
    script_run("srun --uid=$users{user_2} --account=UNI_X_IT -N 2 hostname");

    script_run("srun --uid=$users{user_3} --account=UNI_Y_Biology -N 3 date");
    script_run("srun --uid=$users{user_4} --account=UNI_Y_Physics -N 3 hostname");

    #Yet another sleep. Slurm.conf::JobAcctGatherFrequency=12
    #In order to allow information to be dumped to the DB, we need to wait some time
    sleep(30);

    my $jobs = script_output("sacct -n -p --starttime 2010-01-01 --format=User,Account,JobID,Jobname,partition,state,time,start,end,elapsed,MaxRss,MaxVMSize,nnodes,ncpus,nodelist");

    #check if there are expected srun jobs being recorded in the accounting db
    $result = 1 unless (($jobs =~ /$users{user_1}/) &&
        ($jobs =~ /$users{user_2}/) &&
        ($jobs =~ /$users{user_3}/) &&
        ($jobs =~ /$users{user_4}/));

    ##check the content directly in the db; see: bugzilla#1150565
    # This is only for information now
    # TODO: consider adding sanity checks - direct checks in the db - for some tests
    my $db_elements = script_output("mysql -h slave-node02.openqa.test -uslurm -e \"use slurm_acct_db; select * from linux_job_table;\"");
    record_info('INFO DB', "$db_elements");

  FAIL:
    my %results = generate_results($name, $description, $result);
    return %results;
}

sub run {
    my $self       = shift;
    my $nodes      = get_required_var('CLUSTER_NODES');
    my $slurm_conf = get_required_var('SLURM_CONF');
    $self->prepare_user_and_group();

    # provision HPC cluster, so the proper rpms are installed,
    # munge key is distributed to all nodes, so is slurm.conf
    # and proper services are enabled and started
    zypper_call('in slurm slurm-munge slurm-torque');

    #types of slurm set-ups: basic, accounting, ha, nfs_db
    if ($slurm_conf =~ /ha/) {
        $self->mount_nfs();
    } elsif ($slurm_conf =~ /accounting/) {
        zypper_call('in mariadb');
    } elsif ($slurm_conf =~ /nfs_db/) {
        zypper_call('in mariadb');
        $self->mount_nfs();
    }

    $self->prepare_slurm_conf();
    record_info('slurmctl conf', script_output('cat /etc/slurm/slurm.conf'));
    $self->distribute_munge_key();
    $self->distribute_slurm_conf();
    barrier_wait('SLURM_SETUP_DONE');

    $self->enable_and_start('munge');
    systemctl('is-active munge');
    barrier_wait('SLURM_SETUP_DBD');

    $self->enable_and_start('slurmctld');
    systemctl('is-active slurmctld');
    $self->enable_and_start('slurmd');
    systemctl('is-active slurmd');

    # wait for slave to be ready
    barrier_wait('SLURM_MASTER_SERVICE_ENABLED');
    barrier_wait('SLURM_SLAVE_SERVICE_ENABLED');

    $self->check_nodes_availability();

    my $file = 'tmpresults.xml';
    assert_script_run("touch $file");
    script_run("echo \"<testsuite name='HPC single tests'>\" >> $file");

    my %test;
    %test = basic_test_01();
    pars_results(%test);

    %test = basic_test_02();
    pars_results(%test);

    %test = basic_test_04();
    pars_results(%test);

    %test = basic_test_05();
    pars_results(%test);

    if ($slurm_conf =~ /nfs_db/) {
        %test = accounting_test_01();
        pars_results(%test);
    } elsif ($slurm_conf =~ /accounting/) {
        %test = accounting_test_01();
        pars_results(%test);
    }

    script_run("echo \"</testsuite>\" >> $file");
    parse_extra_log('XUnit', 'tmpresults.xml');

    barrier_wait('SLURM_MASTER_RUN_TESTS');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
    $self->upload_service_log('slurmctld');
    $self->upload_service_log('slurmdbd');
    upload_logs('/var/log/slurmctld.log');
}

1;
