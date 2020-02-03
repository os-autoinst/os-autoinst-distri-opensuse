# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
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
use base 'hpc::test_runner';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use Data::Dumper;
use Mojo::JSON;

sub run_tests {
    my ($slurm_conf) = @_;

    my @all_tests_results;

    # always run basic tests
    push(@all_tests_results, run_basic_tests());

    if ($slurm_conf =~ /ha/) {
        push(@all_tests_results, run_ha_tests());
    } elsif ($slurm_conf =~ /accounting/) {
        push(@all_tests_results, run_accounting_tests());
    } elsif ($slurm_conf =~ /nfs_db/) {
        # this set-up allows both, ha and accounting tests
        push(@all_tests_results, run_accounting_tests());
        push(@all_tests_results, run_ha_tests());
    }

    pars_results(@all_tests_results);
}

########################################
## Basic tests: for HPC/slurm cluster ##
## 1 master node, 2+ slave nodes      ##
########################################
sub run_basic_tests {
    my @all_results;

    my %test00 = t00_version_check();
    push(@all_results, \%test00);

    my %test01 = t01_basic();
    push(@all_results, \%test01);

    my %test02 = t02_basic();
    push(@all_results, \%test02);

    my %test03 = t03_basic();
    push(@all_results, \%test03);

    my %test04 = t04_basic();
    push(@all_results, \%test04);

    if (get_required_var('VERSION') =~ m/15-SP2/) {
        my %test05 = t05_basic();
        push(@all_results, \%test05);
    }

    my %test06 = t06_basic();
    push(@all_results, \%test06);

    my %test07 = t07_basic();
    push(@all_results, \%test07);

    return @all_results;
}

sub t00_version_check {
    my $description = 'Simple SINFO version print for ease of checking';

    my $result = script_output('sinfo --version');
    my $name   = "Sinfo: slurm version check: $result";

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub t01_basic {
    my $name        = 'Srun check: -w';
    my $description = 'Basic SRUN test with -w option';

    my $result = script_run("srun -w slave-node00 date");

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub t02_basic {
    my $name        = 'Sinfo check';
    my $description = 'Simple SINFO test';

    my $result = script_run('sinfo');

    ##TODO: add check of sinfo vs slurm.conf?

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub t03_basic {
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

sub t04_basic {
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

sub t05_basic {
    my $name        = 'PMIx Support in SLURM and the MPI Libraries';
    my $description = 'Basic check if pmix is present. https://jira.suse.com/browse/SLE-10802';
    my $result      = 0;

    my $pmi_versions = script_output("srun --mpi=list");
    $result = 1 unless ($pmi_versions =~ m/pmix/);
    record_info('INFO', script_output("srun --mpi=list"));

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub t06_basic {
    my $name          = 'Srun check: -N -n';
    my $description   = 'Basic SRUN test with -N and -n option';
    my $cluster_nodes = get_required_var('CLUSTER_NODES');

    my $result = script_run("srun -N $cluster_nodes -n $cluster_nodes date");

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub t07_basic {
    my $name          = 'Srun check: -w';
    my $description   = 'Basic SRUN test with -w option on multiple nodes';
    my $cluster_nodes = get_required_var('CLUSTER_NODES');

    ##TODO: remove hardcoded slaves
    my $result = script_run("srun -w slave-node00,slave-node01 date");

    my %results = generate_results($name, $description, $result);
    return %results;
}

#############################################
## Accounting tests: for HPC/slurm cluster ##
#############################################

sub run_accounting_tests {
    my @all_results;

    my %test01 = t01_accounting();
    push(@all_results, \%test01);

    return @all_results;
}

sub t01_accounting {
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

    # this is required; see: bugzilla#1150565?
    systemctl('restart slurmctld');
    systemctl('is-active slurmctld');

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

#####################################
## HA tests: for HPC/slurm cluster ##
#####################################

sub run_ha_tests {
    my @all_results;

    my %test01 = t01_ha();
    push(@all_results, \%test01);

    my %test02 = t02_ha();
    push(@all_results, \%test02);

    return @all_results;
}

sub t01_ha {
    my $name          = 'scontrol: slurm ctl fail-over';
    my $description   = 'HPC cluster with 2 slurm ctls where one is taking over gracefully';
    my $cluster_nodes = get_required_var('CLUSTER_NODES');
    my $result        = 1;
    my @all_results;

    for (my $i = 0; $i <= 100; $i++) {
        if ($i == 50) {
            assert_script_run('scontrol takeover');
        }
        $result = script_run("srun -N $cluster_nodes date");
        push(@all_results, $result);
    }

    foreach (@all_results) {
        if ($_ == 0) {
            $result = 0;
            last;
        }
    }

    my %results = generate_results($name, $description, $result);
    return %results;
}

sub t02_ha {
    my $name          = 'kill: Slurm ctl fail-over';
    my $description   = 'HPC cluster with 2 slurm ctls where one is killed';
    my $cluster_nodes = get_required_var('CLUSTER_NODES');
    my $result        = 1;
    my @all_results;

    systemctl('start slurmctld');
    systemctl('is-active slurmctld');

    for (my $i = 0; $i <= 100; $i++) {
        if ($i == 50) {
            my $pidofslurmctld = script_output('pidof slurmctld');
            script_run("kill $pidofslurmctld");
        }
        $result = script_run("srun -N $cluster_nodes date -R");
        push(@all_results, $result);
    }

    foreach (@all_results) {
        if ($_ == 0) {
            $result = 0;
            last;
        }
    }

    my %results = generate_results($name, $description, $result);
    return %results;
}

################################################
## Accounting and HA: for HPC/slurm cluster ####
################################################

sub run_accounting_ha_tests {
    my @all_results;

    ##TODO

    return @all_results;
}

sub run {
    my $self       = shift;
    my $nodes      = get_required_var('CLUSTER_NODES');
    my $slurm_conf = get_required_var('SLURM_CONF');
    my $version    = get_required_var('VERSION');

    barrier_wait('CLUSTER_PROVISIONED');
    $self->prepare_user_and_group();
    $self->generate_and_distribute_ssh();

    # provision HPC cluster, so the proper rpms are installed,
    # munge key is distributed to all nodes, so is slurm.conf
    # and proper services are enabled and started
    zypper_call('in slurm slurm-munge slurm-torque');

    if ($slurm_conf =~ /ha/) {
        $self->mount_nfs();
    } elsif ($slurm_conf =~ /accounting/) {
        zypper_call('in mariadb');
    } elsif ($slurm_conf =~ /nfs_db/) {
        zypper_call('in mariadb');
        $self->mount_nfs();
    }

    $self->prepare_slurm_conf();
    if ($version !~ /15-SP2/) {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\ControlMachine=master-node00" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    } else {
        my $config = << "EOF";
sed -i "/^ControlMachine.*/c\\#ControlMachine" /etc/slurm/slurm.conf
EOF
        assert_script_run($_) foreach (split /\n/, $config);
    }
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

    ## TEST RUN ##
    ## Prepared HPC cluster should run tests based on its capabilities
    # slurm supported configurations:
    # BASIC: 1 slurm ctl and 2+ compute nodes
    # HA: 2 slurm ctl and 2+ compute nodes
    # ACCOUNTING: 1 slurm ctl, 1 slurmdbd, 2+ compute nodes
    # ACCOUNTING and HA (nfs_db): 2 slurm ctl, 1 slurmdbd, 2+ compute nodes

    run_tests($slurm_conf);

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
