use base "installbasetest";

use testapi;

use strict;
use warnings;

use Net::SSH::Perl;

sub run() {

    my $self = shift;

    my $zkvm_host     = get_var('ZKVM_HOST');
    my $zkvm_password = get_var('ZKVM_PASSWORD');

    my $zkvm_guest_ip         = '10.161.145.6';
    my $zkvm_guest_netmask    = '20';
    my $zkvm_guest_gateway    = '10.161.159.254';
    my $zkvm_guest_nameserver = '10.160.0.1';
    my $zkvm_guest_domain     = 'suse.de';

    select_console('svirt');

    my $instance = get_var('ZKVM_INSTANCE') || '1';
    my $xml = <<EOT;
<?xml version="1.0"?>
<domain type="kvm">
  <name>openQA-SUT-$instance</name>
  <description>Just a TEST</description>
  <memory unit="KiB">524288</memory>
  <vcpu>1</vcpu>
  <os>
    <type arch="s390x" machine="s390-ccw-kvmibm-1.1.0">hvm</type>
    <kernel>/var/lib/libvirt/images/openQA-SUT-$instance.kernel</kernel>
    <initrd>/var/lib/libvirt/images/openQA-SUT-$instance.initrd</initrd>
    <cmdline>ifcfg=*=$zkvm_guest_ip/$zkvm_guest_netmask,$zkvm_guest_gateway,$zkvm_guest_nameserver,$zkvm_guest_domain install=ftp://openqa.suse.de/SLE-12-SP1-Server-DVD-s390x-Build3244-Media1/ vnc=1 VNCPassword=$testapi::password sshpassword=$testapi::password sshd=1</cmdline>
    <boot dev="hd"/>
  </os>
  <iothreads>1</iothreads>
  <clock offset="utc"/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>destroy</on_reboot>
  <on_crash>preserve</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-s390x</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="/var/lib/libvirt/images/openQA-SUT-$instance.img"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <interface type="direct">
      <source dev="enccw0.0.0600" mode="bridge"/>
      <target dev="macvtap1"/>
    </interface>
    <interface type="direct">
      <source dev="enccw0.0.0600" mode="bridge"/>
      <target dev="macvtap2"/>
    </interface>
    <console type="pty">
      <target type="sclp" port="0"/>
    </console>
  </devices>
</domain>
EOT

    my $ssh = Net::SSH::Perl->new($zkvm_host);
    $ssh->login('root', $zkvm_password);

    my ($out, $err, $exit) = $ssh->cmd("cat > /var/lib/libvirt/images/openQA-SUT-$instance.xml", $xml);
    die "cat failed: $err" if $exit;

    # shut down possibly running previous test (just to be sure) - ignore errors
    $ssh->cmd("virsh destroy openQA-SUT-$instance");
    $ssh->cmd("virsh undefine openQA-SUT-$instance");

    # show this on screen
    type_string "wget ftp://openqa.suse.de/SLE-12-SP1-Server-DVD-s390x-Build3244-Media1/boot/s390x/initrd -O /var/lib/libvirt/images/openQA-SUT-$instance.initrd\n";
    sleep 2;    # TODO: assert_screen
    type_string "wget ftp://openqa.suse.de/SLE-12-SP1-Server-DVD-s390x-Build3244-Media1/boot/s390x/linux -O /var/lib/libvirt/images/openQA-SUT-$instance.kernel\n";
    sleep 2;    # TODO: assert_screen

    ($out, $err, $exit) = $ssh->cmd("qemu-img create /var/lib/libvirt/images/openQA-SUT-$instance.img 4G -f qcow2");
    die "virsh failed: $err" if $exit;

    # define the new domain
    ($out, $err, $exit) = $ssh->cmd("virsh define /var/lib/libvirt/images/openQA-SUT-$instance.xml");
    die "virsh failed: $err" if $exit;
    ($out, $err, $exit) = $ssh->cmd("virsh start openQA-SUT-$instance");
    die "virsh failed: $err" if $exit;


    type_string "virsh console openQA-SUT-$instance\n";
    # now wait
    assert_screen('starting_yast', 300);

    select_console('installation');

}

1;
