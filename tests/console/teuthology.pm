# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run teuthology suites via ECP or OVH openstack and get results and logs
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

my $incidentnr    = get_var('INCIDENT_ID');
my $suite         = get_var('TEUTHOLOGY_SUITE');
my $ses_version   = is_sle('=15') ? 'ses6' : 'ses5';
my $instance_name = "QAM-$incidentnr-openqa-$ses_version";

sub upload_teuthology_logs {
    # get all teuthology logs, tar them and upload
    upload_logs "teuthology-openstack-$suite.log";
    assert_script_run "export COUNT=\$(grep openstack/[[:digit:]]/teuthology teuthology-openstack-$suite.log|wc -l)";
    assert_script_run "for c in `seq 1 \$COUNT`; do for l in `grep \"openstack/\$c/teuthology.log\" \\
teuthology-openstack-$suite.log|awk '{print\$6}'`;do wget \$l && mv teuthology.log teuthology_target_\$c.log; done; done";
    assert_script_run "tar zcvf teuthology_targets.tar.gz teuthology_target_*";
    upload_logs 'teuthology_targets.tar.gz';
}

sub openstack_cleanup {
    # delete existing server, keypair and security group of same MR instance
    script_run "openstack server delete teuth-$instance_name";
    script_run "openstack keypair delete teuth-$instance_name";
    script_run "openstack security group delete teuth-$instance_name";
}

sub run {
    select_console 'root-console';
    # export variables for teardown of openstack VM in next test
    assert_script_run "export instance_name=$instance_name";
    # TODO select ECP or OVH, now is ECP preconfigured in disk image
    assert_script_run 'openstack keypair list';
    assert_script_run 'openstack server list';
    openstack_cleanup;
    # parse maintenance repos into variable for teuthology repos
    my @repos      = split(/,/, get_var('MAINT_TEST_REPO'));
    my $repo_count = 1;
    my $maint_test_repos;
    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        $maintrepo = "--test-repo maint_repo$repo_count:$maintrepo";
        $maint_test_repos .= " " . $maintrepo;
        $repo_count++;
    }
    # run teuthology openstack in ECP or OVH
    assert_script_run "teuthology-openstack -v --key-filename ~/.ssh/id_rsa --key-name QAM-openqa --name $instance_name \\
--simultaneous-jobs 20 --teuthology-git-url http://github.com/SUSE/teuthology --teuthology-branch master \\
--suite-repo http://github.com/SUSE/ceph --suite-branch $ses_version \\
--ceph-repo http://github.com/SUSE/ceph --ceph $ses_version --suite $suite --filter sle $maint_test_repos \\
--test-repo sle12_product:http://download.suse.de/ibs/SUSE/Products/SLE-SERVER/12-SP3/x86_64/product/ \\
--test-repo sle12_update:http://download.suse.de/ibs/SUSE/Updates/SLE-SERVER/12-SP3/x86_64/update/ \\
--test-repo ses5_product:http://download.suse.de/ibs/SUSE/Products/Storage/5/x86_64/product/ \\
--test-repo ses5_update:http://download.suse.de/ibs/SUSE:/SLE-12-SP3:/Update:/Products:/SES5:/Update/standard/ \\
--wait |& tee teuthology-openstack-$suite.log; if [ \${PIPESTATUS[0]} -ne 0 ]; then false; fi", 7000;
    # get pulpito webui ip from log
    assert_script_run "export PULPITO=\$(grep 'pulpito web interface:' teuthology-openstack-$suite.log|awk -F'//|:' '{print\$4}'|uniq)";
    assert_script_run "sed -i \"/\$PULPITO/d\" /etc/hosts";
    assert_script_run "echo \"\$PULPITO pulpito.suse.de pulpito\" >>/etc/hosts";
    assert_script_run 'cat /etc/hosts';
    # ssh to teuthology machine not used now
    assert_script_run "SSH=\$(grep 'ssh access' teuthology-openstack-$suite.log|awk -F': | #' '{print\$2}'|uniq)";
    assert_script_run 'export SSH="$SSH -oStrictHostKeyChecking=no"';
}

sub post_run_hook {
    upload_teuthology_logs;
}

sub post_fail_hook {
    upload_teuthology_logs;
}

sub test_flags {
    return {fatal => 1};
}

1;
