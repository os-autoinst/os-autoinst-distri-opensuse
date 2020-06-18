# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify installation starts and is in progress
# Maintainer: Michael Moese <mmoese@suse.de>
use strict;
use warnings;
use base 'opensusebasetest';

use testapi;
use bmwqemu;
use utils;

use HTTP::Tiny;

my @vm_ips;

sub create_vms {
    my $self = shift;

    my $distri = get_required_var('DISTRI');
    my $ver    = get_required_var('VERSION');

    $ver =~ tr/-//;    # remove the - in the string
    my $os_variant = $distri . $ver;

    my @vfns = split(' ', script_output('lspci -D | grep Mellanox | grep Virtual | awk \'{ print $1}\''));

    my $vm_count = get_var('VM_COUNT', '1');
    my $vm_mem   = get_var('VM_MEM',   '2048');
    my $vm_vcpu  = get_var('VM_VCPU',  '2');
    my $virtinst_parm = "--os-type=Linux --os-variant=$os_variant --ram=$vm_mem --vcpus=$vm_vcpu --graphics=none --network network=default --import --noautoconsole --noreboot";

    my $count = 0;
    my @vm_ips;

    foreach (@vfns) {
        my $libvirt_nodedev = $_;
        $libvirt_nodedev =~ tr/:./_/;
        my $img = "/var/lib/libvirt/images/vm_$_.qcow2";
        assert_script_run("qemu-img create -f qcow2 -o backing_file=/var/lib/libvirt/images/master.qcow2 $img");

        # create the machine, but don't run it yet - otherwise virt-install
        # will wait for the installation to finish, but we don't perform an
        # installation here.
        assert_script_run(
            "virt-install --name vm_$_ --description \"vm for $_\" --disk path=$img --host-device=pci_$libvirt_nodedev $virtinst_parm "
        );
        assert_script_run("virsh start vm_$_");
        sleep(120);
        assert_script_run("virsh console vm_$_");
        type_string("root\n");
        type_password;
        send_key("ret");
        my $str = script_output('ip addr show dev eth0 | grep "inet "');
        type_string("\c]");
        $str =~ s/^\s+//;
        my @ip = split(/[\s,\/]/, $str);
        push(@vm_ips, $ip[1]);

        $count = $count + 1;
        last if $count == $vm_count;
    }
}

sub run {
    my $self = shift;
    # those IP's represent the host machines that we start the VM's on
    my $host1 = get_required_var('VM_HOST_1');
    my $host2 = get_required_var('VM_HOST_2');

    my $arch        = get_required_var('ARCH');
    my $build       = get_required_var('BUILD');
    my $distri      = get_required_var('DISTRI');
    my $flavor      = get_required_var('FLAVOR');
    my $version     = get_required_var('VERSION');
    my $http_server = get_required_var('BAREMETAL_SUPPORT_SERVER');

    my $test = get_var('GET_IMAGE_FROM_TEST', 'create_hdd_textmode');

    my $url      = "$http_server/v1/latest_job/$arch/$distri/$flavor/$version/$test";
    my $response = HTTP::Tiny->new->request('GET', $url);
    my $jobid    = $response->{content};

    my $openqa_host = get_required_var('MIRROR_HTTP');
    $openqa_host =~ m|^( .*?\. [^/]+ )|x;

    $self->select_serial_terminal;

    # make sure we have a ssh key
    script_run('[ ! -f /root/.ssh/id_rsa] && ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');

    # start the VM's for each host
    foreach ($host1, $host2) {
        script_run("/usr/bin/clear");
        exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$_");
        assert_script_run("scp /root/id_rsa root@$_/.ssh/id_rsa");
        assert_script_run("scp /root/id_rsa.pub root@$_/.ssh/id_rsa.pub");
        assert_script_run("ssh root@$_");

        # we need openqa2vm, so lets add the repo
        zypper_ar('https://download.opensuse.org/repositories/home:/czerw:/openqa2vm/openSUSE_Leap_15.1/home:czerw:openqa2vm.repo', no_gpg_check => 1);

        # make sure we install the requirements: kvm, libvirt, qemu, virt-install, openqa2vm, expect and dependencies
        zypper_call('in libvirt virt-install openqa2vm, expect');

        systemctl('enable --now libvirt');
        script_run('virsh net-start default');
        script_run('sysctl -w net.ipv4.ip_forward=1');

        # fetch the image from openQA
        assert_script_run("openqa2vm -f $openqa_host -p $jobid");
        my $path  = "/var/tmp/openqa2vm/$openqa_host/$jobid/";
        my $image = script_output("ls $path/$distri-$version-$arch-$build-*.qcow2");
        script_run("mv $image /var/lib/libvirt/master.qcow2");
        script_run("rm -f $image");

        create_vms();
        script_run("exit");
    }
    set_var('IBTEST_IP1', $vm_ips[0]);
    set_var('IBTEST_IP2', $vm_ips[1]);

}

1;
