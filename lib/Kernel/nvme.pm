# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: NVMe over Fabrics target and initiator helpers for kernel tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::nvme;

use Exporter 'import';

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  DEFAULT_NQN
  nvmet_target_create
  nvmet_target_delete
  nvme_discover
  nvme_connect
  nvme_disconnect
  nvme_namespace_by_nqn
);

use constant DEFAULT_NQN => 'nqn.2026-10.de.openqa:nvmet-tcp';

=head1 SYNOPSIS

Utils and helpers for NVMe testing.

On the target:

  use Kernel::nvme qw(nvmet_target_create nvmet_target_delete);
  nvmet_target_delete(nqn => $nqn);
  nvmet_target_create(nqn => $nqn, device => '/dev/vdb', addr => '10.0.2.1');

On the initiator:

  use Kernel::nvme qw(nvme_connect nvme_disconnect);
  my $ns = nvme_connect(nqn => $nqn, addr => '10.0.2.1');    # e.g. 'nvme1n1'
  ...
  nvme_disconnect(nqn => $nqn);

C<DEFAULT_NQN> is the subsystem NQN that the tests use by default.

=cut

my $nvmet_cfs = '/sys/kernel/config/nvmet';

# Mounts configfs, unless it is mounted already.
sub _mount_configfs {
    assert_script_run('mountpoint -q /sys/kernel/config || mount -t configfs none /sys/kernel/config');
}

=head2 nvmet_target_create

  my $subsys = nvmet_target_create(
      nqn    => DEFAULT_NQN,
      device => '/dev/vdb',
      addr   => '10.0.2.1',
  );

Export one block device as namespace 1 of a new NVMe subsystem, configured
through the C<nvmet> configfs on the current SUT. Load the target modules
and mount configfs first. If firewalld is active, open the port in the
runtime configuration. Make sure that the port listens.

Arguments:
  nqn       - Subsystem NQN. Required.
  device    - Block device or file to export as namespace 1. Required.
  addr      - Address the port listens on (addr_traddr). Required.
  port      - TCP port (addr_trsvcid). Default: 4420.
  port_id   - Directory name of the port in the configfs. Default: 1.
  trtype    - Transport type. Default: 'tcp'.
  adrfam    - Address family. Default: 'ipv4'.
  hostnqn   - Host NQN to allow. Default: none, any host can connect.

Returns: the configfs path of the subsystem.

=cut

sub nvmet_target_create {
    my (%args) = @_;
    my $nqn = $args{nqn} // die 'nvmet_target_create requires nqn';
    my $device = $args{device} // die 'nvmet_target_create requires device';
    my $addr = $args{addr} // die 'nvmet_target_create requires addr';
    my $port = $args{port} // 4420;
    my $port_id = $args{port_id} // 1;
    my $trtype = $args{trtype} // 'tcp';
    my $adrfam = $args{adrfam} // 'ipv4';
    my $subsys = "$nvmet_cfs/subsystems/$nqn";
    my $port_dir = "$nvmet_cfs/ports/$port_id";

    assert_script_run('modprobe nvmet');
    assert_script_run("modprobe nvmet-$trtype");
    _mount_configfs();

    assert_script_run("mkdir $subsys");
    if (my $hostnqn = $args{hostnqn}) {
        assert_script_run("echo 0 > $subsys/attr_allow_any_host");
        assert_script_run("mkdir -p $nvmet_cfs/hosts/$hostnqn");
        assert_script_run("ln -s $nvmet_cfs/hosts/$hostnqn $subsys/allowed_hosts/$hostnqn");
    } else {
        assert_script_run("echo 1 > $subsys/attr_allow_any_host");
    }
    assert_script_run("mkdir $subsys/namespaces/1");
    assert_script_run("echo -n $device > $subsys/namespaces/1/device_path");
    assert_script_run("echo 1 > $subsys/namespaces/1/enable");

    assert_script_run("mkdir $port_dir");
    assert_script_run("echo $trtype > $port_dir/addr_trtype");
    assert_script_run("echo $adrfam > $port_dir/addr_adrfam");
    assert_script_run("echo $addr > $port_dir/addr_traddr");
    assert_script_run("echo $port > $port_dir/addr_trsvcid");
    assert_script_run("ln -s $subsys $port_dir/subsystems/$nqn");

    if ($trtype eq 'tcp') {
        assert_script_run("firewall-cmd --add-port=$port/tcp") if script_run('systemctl is-active -q firewalld') == 0;
        assert_script_run("ss -Hltn 'sport = :$port' | grep -q .", fail_message => "NVMe/TCP target does not listen on port $port");
    }
    record_info('nvmet', "$nqn\nnamespace 1: $device\n$trtype $addr:$port");
    return $subsys;
}

=head2 nvmet_target_delete

  nvmet_target_delete(nqn => $nqn);

Remove the subsystem C<nqn> and the port C<port_id> (default: 1) that
C<nvmet_target_create> made. Ignore the parts that do not exist, so you can
use it to clean up before C<nvmet_target_create>. The port stays if another
subsystem uses it.

=cut

sub nvmet_target_delete {
    my (%args) = @_;
    my $nqn = $args{nqn} // die 'nvmet_target_delete requires nqn';
    my $port_id = $args{port_id} // 1;
    my $subsys = "$nvmet_cfs/subsystems/$nqn";
    my $port_dir = "$nvmet_cfs/ports/$port_id";

    script_run("if test -d $subsys; then "
          . "rm -f $port_dir/subsystems/$nqn; "
          . "rmdir $port_dir; "
          . "echo 0 > $subsys/namespaces/1/enable; "
          . "rmdir $subsys/namespaces/1; "
          . "rm -f $subsys/allowed_hosts/*; "
          . "rmdir $subsys; fi");
    assert_script_run("! test -d $subsys", fail_message => "Cannot remove nvmet subsystem $nqn");
}

=head2 nvme_discover

  my $log = nvme_discover(addr => '10.0.2.1');

Load the host module of the transport and run C<nvme discover> against a
target. Return the discovery log. Arguments C<addr> (required), C<port>
(default: 4420) and C<trtype> (default: 'tcp').

=cut

sub nvme_discover {
    my (%args) = @_;
    my $addr = $args{addr} // die 'nvme_discover requires addr';
    my $port = $args{port} // 4420;
    my $trtype = $args{trtype} // 'tcp';

    assert_script_run("modprobe nvme-$trtype");
    return script_output("nvme discover -t $trtype -a $addr -s $port");
}

=head2 nvme_connect

  my $ns = nvme_connect(nqn => $nqn, addr => '10.0.2.1');

Load the host module of the transport and connect to the subsystem C<nqn>.
Wait for its namespace, see C<nvme_namespace_by_nqn>.

Arguments:
  nqn       - Subsystem NQN. Required.
  addr      - Target address. Required.
  port      - Target port. Default: 4420.
  trtype    - Transport type. Default: 'tcp'.
  hostnqn   - Host NQN. Default: the one of nvme-cli (/etc/nvme/hostnqn).

Returns: the block device name of the namespace, e.g. C<nvme1n1>.

=cut

sub nvme_connect {
    my (%args) = @_;
    my $nqn = $args{nqn} // die 'nvme_connect requires nqn';
    my $addr = $args{addr} // die 'nvme_connect requires addr';
    my $port = $args{port} // 4420;
    my $trtype = $args{trtype} // 'tcp';
    my $hostnqn = $args{hostnqn} ? " --hostnqn $args{hostnqn}" : '';

    assert_script_run("modprobe nvme-$trtype");
    assert_script_run("nvme connect -t $trtype -a $addr -s $port -n $nqn$hostnqn");
    return nvme_namespace_by_nqn(nqn => $nqn);
}

=head2 nvme_disconnect

  nvme_disconnect(nqn => $nqn);
  nvme_disconnect(nqn => $nqn, may_fail => 1);

Disconnect all controllers of the subsystem C<nqn>. With C<may_fail>, do
not fail if no controller is connected, e.g. to clean up before
C<nvme_connect>.

=cut

sub nvme_disconnect {
    my (%args) = @_;
    my $nqn = $args{nqn} // die 'nvme_disconnect requires nqn';
    my $cmd = "nvme disconnect -n $nqn";

    return script_run($cmd) if $args{may_fail};
    assert_script_run($cmd);
}

=head2 nvme_namespace_by_nqn

  my $ns = nvme_namespace_by_nqn(nqn => $nqn);
  my $ns = nvme_namespace_by_nqn(nqn => $nqn, timeout => 60);

Find the first namespace block device of the connected subsystem C<nqn>
in C</sys/class/nvme-subsystem>. The kernel scans the namespaces after the
connect, so wait up to C<timeout> seconds (default: 30).

Returns: the block device name, e.g. C<nvme1n1>. Dies if no namespace
shows up in time.

=cut

sub nvme_namespace_by_nqn {
    my (%args) = @_;
    my $nqn = $args{nqn} // die 'nvme_namespace_by_nqn requires nqn';
    my $timeout = $args{timeout} // 30;
    my $cmd = "s=\$(grep -lx '$nqn' /sys/class/nvme-subsystem/*/subsysnqn) && "
      . "ls \$(dirname \$s) | grep -m1 -E '^nvme[0-9]+n[0-9]+\$'";

    for (1 .. $timeout) {
        my $ns = script_output($cmd, proceed_on_failure => 1);
        return $ns if $ns =~ /^nvme\d+n\d+$/;
        sleep 1;
    }
    die "No namespace of NVMe subsystem $nqn after $timeout seconds";
}

1;
