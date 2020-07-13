# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: switch IPMI to QEMU
# Using the openQA backend can be the advantage of QEMU.
# After completing the physical host through the IPMI backend,
# the SUT is converted into a QEMU virtual machine platform,
# and multiple QEMU workers are started on this platform to complete the KVM virtual machine test.
# The HOST attribute of these workers will be set to openQA's WEBUI server,
# so with the help of the openQA scheduler,
# all QEMU-backed tests will be executed at the end until all physical machine tests are completed.
# Maintainer: James Wang <jnwang@suse.com>

use strict;
use warnings;
use Mitigation;
use base "consoletest";
use bootloader_setup;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;
use version_utils 'get_sles_release';
my $cliect_ini_url    = get_var('CLIENT_INI');
my $webui_hostname    = get_var('WEBUI_HOSTNAME');
my $nfs_hostname      = get_var('NFS_HOSTNAME');
my $qemu_worker_class = get_var('QEMU_WORKER_CLASS');
sub run {
    my $self = shift;
    my $current_dist;
    script_run("systemctl disable apparmor.service");
    script_run("aa-teardown");
    my ($sles_running_version, $sles_running_sp) = get_sles_release();
    if ($sles_running_sp gt '0') {
        $current_dist = sprintf("SLE_%s_SP%s", $sles_running_version, $sles_running_sp);
    } else {
        $current_dist = sprintf("SLE_%s", $sles_running_version);
    }
    die "Fail to get SLES release version" unless $current_dist;
    zypper_call("rr devel_languages_perl devel_openQA devel_openQA_SLE-$sles_running_version");
    zypper_call("ar http://download.opensuse.org/repositories/devel:/languages:/perl/$current_dist/devel:languages:perl.repo");
    zypper_call("ar http://download.opensuse.org/repositories/devel:/openQA/$current_dist/devel:openQA.repo");
    zypper_call("ar http://download.opensuse.org/repositories/devel:/openQA:/SLE-$sles_running_version/$current_dist/devel:openQA:SLE-$sles_running_version.repo");
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('dup --auto-agree-with-licenses');
    zypper_call('in openQA-worker perl-DBIx-Class-DeploymentHandler perl-YAML-Tiny perl-Test-Assert');
    zypper_call('in --replacefiles perl-DBD-SQLite');

    #NFS mount
    #assert_script_run("mount -t nfs $nfs_hostname:/var/lib/openqa/share /var/lib/openqa/share");

    #Rsync
    if (script_run("grep \"^\\[http://$nfs_hostname\\]\" /etc/openqa/workers.ini") eq 1) {
        assert_script_run("echo \"[http://$nfs_hostname]\" >> /etc/openqa/workers.ini");
        assert_script_run("echo \"TESTPOOLSERVER = rsync://$nfs_hostname/tests\" >>/etc/openqa/workers.ini");
    }
    if (script_run("grep \"^CACHEDIRECTORY = /var/lib/openqa/cache\" /etc/openqa/workers.ini") eq 1) {
        assert_script_run("sed -i '/^#HOST.*=.*/a CACHELIMIT = 200' /etc/openqa/workers.ini");
        assert_script_run("sed -i '/^#HOST.*=.*/a CACHEDIRECTORY = /var/lib/openqa/cache' /etc/openqa/workers.ini");
    }

    assert_script_run("sed -i '/^#.*global/s/^#//' /etc/openqa/workers.ini");
    assert_script_run("sed -i '/^HOST =.*/d' /etc/openqa/workers.ini");


    if (script_run("grep \"^#HOST.*=.*\" /etc/openqa/workers.ini") == 0) {
        assert_script_run("sed -i '/^#HOST.*=.*/a HOST = $webui_hostname' /etc/openqa/workers.ini");
    } else {
        assert_script_run("sed -i '/^\\[global\\]/a HOST = $webui_hostname' /etc/openqa/workers.ini");
    }
    assert_script_run("sed -i '/^WORKER_CLASS =.*/d' /etc/openqa/workers.ini");
    assert_script_run("sed -i '/WORKER_HOSTNAME =.*/a WORKER_CLASS = $qemu_worker_class' /etc/openqa/workers.ini");
    assert_script_run(
        'curl '
          . $cliect_ini_url
          . ' -o /etc/openqa/client.conf',
        60
    );
    script_run('systemctl start openqa-worker-cacheservice-minion');
    script_run('systemctl start openqa-worker-cacheservice');
    script_run('systemctl start openqa-worker@{1..8}');
}

#There will collect a lot of information that I don't need it.
#The screen log is enough.
sub post_fail_hook {
    my ($self) = @_;
}

1;

