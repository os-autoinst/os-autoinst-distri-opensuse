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
    my (@test) = @_;
    my $file = 'tmpresults.xml';

    # check if there are some single test failing
    # and if so, make sure the whole testsuite will fail
    my $fail_check = 0;
    for my $i (@test) {
        if ($i->{result} eq 'FAIL') {
            $fail_check++;
        }
    }

    if ($fail_check > 0) {
        script_run("echo \"<testsuite name='HPC single tests' errors='1'>\" >> $file");
    } else {
        script_run("echo \"<testsuite name='HPC single tests'>\" >> $file");
    }

    # pars all results and provide expected xml file
    for my $i (@test) {
        if ($i->{result} eq 'FAIL') {
            script_run("echo \"<testcase name='$i->{test}' errors='1'>\" >>  $file");
        } else {
            script_run("echo \"<testcase name='$i->{test}'>\" >> $file");
        }
        script_run("echo \"<system-out>\" >> $file");
        script_run("echo $i->{description} >>  $file");
        script_run("echo \"</system-out>\" >> $file");
        script_run("echo \"</testcase>\" >> $file");
    }
}

sub run_tests {
    my ($slurm_conf) = @_;

    my $file = 'tmpresults.xml';
    assert_script_run("touch $file");

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

    script_run("echo \"</testsuite>\" >> $file");
    parse_extra_log('XUnit', 'tmpresults.xml');
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

    my %test08 = t08_basic();
    push(@all_results, \%test08);

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

sub t08_basic {
    my $name        = 'pdsh-slurm';
    my $description = 'Basic check of pdsh-slurm over ssh';
    my $result      = 0;

    zypper_call('in pdsh pdsh-slurm');

    my $sinfo_nodeaddr = script_output('sinfo -a --Format=nodeaddr -h');
    my $pdsh_nodes     = script_output('pdsh -R ssh -P normal /usr/bin/hostname');
    my @sinfo_nodeaddr = (split ' ', $sinfo_nodeaddr);

    foreach my $i (@sinfo_nodeaddr) {
        if (index($pdsh_nodes, $i) == -1) {
            $result = 1;
            last;
        }
    }

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

    record_info('INFO DB', "$jobs");

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

###############################################
##        Extended tests for HPC cluster     ##
##          Meant as fast moving tests       ##
###############################################

sub extended_hpc_tests {
    #install some tools needed for extended tests
    zypper_call('in git gcc bc');

    #ensure HPC cluster installs needed rpms
    zypper_call('in openmpi3 openmpi3-gnu-hpc openmpi3-gnu-hpc-devel bc openmpi3-devel');
    zypper_call('in pmix hypre_*-gnu-*-hpc* cpuid papi_*-hpc boost_*-gnu-hpc gsl_*-gnu-hpc petsc_*-gnu-*-hpc*');
    script_run('export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib64/mpi/gcc/openmpi3/lib64/');
    script_run('wget --quiet ' . data_url('hpc/simple_mpi.c') . ' -O /tmp/simple_mpi.c');
    script_run('/usr/lib64/mpi/gcc/openmpi3/bin/mpicc /tmp/simple_mpi.c -o /tmp/simple_mpi | tee /tmp/make.out');
    script_run('git clone https://github.com/schlad/havoxc_binary.git');
    script_run('cd havoxc_binary');
    script_run('wget --quiet ' . data_url('hpc/julog.sh') . ' -O julog.sh');
    script_run('./havoxc.so', 180);
    parse_extra_log('XUnit', './results/TEST-havoxc_so.xml');
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
    # EXT_HPC_TESTS: special variable to enable extended and external HPC tests
    # Those EXT_HPC_TESTS are meant as fast-moving, quick tests not meant for
    # stability; use at your own risk

    if (get_required_var('EXT_HPC_TESTS')) {
        extended_hpc_tests();
    } else {
        run_tests($slurm_conf);
    }

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
    $self->export_logs_basic;
    $self->get_remote_logs('slave-node02', 'slurmdbd.log');
    upload_logs('/var/log/slurmctld.log');
}

1;
