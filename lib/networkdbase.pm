# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base module for all networkd scenarios
# Maintainer: Dominik Heidler <dheidler@suse.de>

package networkdbase;

use strict;
use warnings;
use testapi;
use utils;

use base 'consoletest';

=head2 assert_script_run_container

 assert_script_run_container($machine, $script);

Run C<$script> in the systemd-nspawn container called C<$machine>.

=cut
sub assert_script_run_container {
    my ($self, $machine, $script) = @_;
    assert_script_run("systemd-run -tM $machine /bin/bash -c \"$script\"");
}

=head2 start_nspawn_container

 start_nspawn_container($machine);

Start the systemd-nspawn container called C<$machine>.

=cut
sub start_nspawn_container {
    my ($self, $machine) = @_;
    assert_script_run("systemctl start systemd-nspawn-openqa@" . $machine);
}

=head2 restart_nspawn_container

 restart_nspawn_container($machine);

Restart the systemd-nspawn container called C<$machine>.

=cut
sub restart_nspawn_container {
    my ($self, $machine) = @_;
    assert_script_run("systemctl stop systemd-nspawn-openqa@" . $machine);
    assert_script_run("systemctl start systemd-nspawn-openqa@" . $machine);
}

=head2 setup_nspawn_container

 setup_nspawn_container($machine, $repo, $packages);

Create a chroot for a systemd-nspawn container called C<$machine>.
Use C<zypper> to add a repo to the chroot and install (with C<--no-recommends>)
the packages listed in C<$packages>.

=cut
sub setup_nspawn_container {
    my ($self, $machine, $repo, $packages) = @_;
    my $path = "/var/lib/machines/$machine";
    assert_script_run("mkdir $path");
    zypper_call("--root $path --gpg-auto-import-keys addrepo $repo defaultrepo");
    zypper_call("--root $path --gpg-auto-import-keys refresh");
    zypper_call("--root $path install --no-recommends -ly $packages", exitcode => [0, 107]);
}

=head2 setup_nspawn_unit

 setup_nspawn_unit();

Create a custom systemd service unit file called C<systemd-nspawn-openqa@.service>.
This will have some custom config that is needed for our tests
(eg. bridged network and binding C</dev/sr0> to access the DVD drive from within the container).

=cut
sub setup_nspawn_unit {
    my ($self) = @_;
    my $systemd_nspawn_openqa_service = "
[Unit]
Description=Container %i
Documentation=man:systemd-nspawn(1)
PartOf=machines.target
Before=machines.target
After=network.target systemd-resolved.service
RequiresMountsFor=/var/lib/machines

[Service]
ExecStart=/usr/bin/systemd-nspawn --quiet --keep-unit --boot --link-journal=try-guest --network-bridge=br0 --bind /dev/sr0 --settings=override --machine=%i
KillMode=mixed
Type=notify
RestartForceExitStatus=133
SuccessExitStatus=133
Slice=machine.slice
Delegate=yes
TasksMax=16384

DevicePolicy=closed
DeviceAllow=/dev/net/tun rwm
DeviceAllow=char-pts rw

# nspawn itself needs access to /dev/loop-control and /dev/loop, to
# implement the --image= option. Add these here, too.
DeviceAllow=/dev/loop-control rw
DeviceAllow=block-loop rw
DeviceAllow=block-blkext rw

[Install]
WantedBy=machines.target
";
    $self->write_file("/etc/systemd/system/systemd-nspawn-openqa@.service", $systemd_nspawn_openqa_service);
}

=head2 write_container_file

 write_container_file($machine, $file, $content);

Create a file at path (including filename) C<$file> within the container called C<$machine>
with the content C<$content>.

=cut
sub write_container_file {
    my ($self, $machine, $file, $content) = @_;
    my $path = "/var/lib/machines/$machine/$file";
    $self->write_file($path, $content);
}

=head2 write_file

 write_file($file, $content);

Helper function to write a file at path (including filename) C<$file> with the content C<$content>.

=cut
sub write_file {
    my ($self, $file, $content) = @_;
    type_string("cat > $file <<EOF\n$content\nEOF\n");
    assert_script_run("test \$? == 0");
}

=head2 wait_for_networkd

 wait_for_networkd($machine, $netif);

Wait until networkd in the container C<$machine> has configured the network interface C<$netif>.

=cut
sub wait_for_networkd {
    my ($self, $machine, $netif) = @_;
    $self->assert_script_run_container($machine, "ip a");
    $self->assert_script_run_container($machine, "networkctl");
    # wait until network is configured
    $self->assert_script_run_container($machine, "for i in {1..20} ; do networkctl | grep $netif.*configured && break ; sleep 1 ; done");
    $self->assert_script_run_container($machine, "networkctl");
    $self->assert_script_run_container($machine, "networkctl | grep $netif.*configured");
    $self->assert_script_run_container($machine, "networkctl status");
}

=head2 export_container_journal

 export_container_journal($machine);

Get the journal from container C<$machine> and upload it to openQA.
This works without interacting with the container as logs are
redirected to the host system journal.

=cut
sub export_container_journal {
    my ($self, $machine) = @_;

    assert_script_run("journalctl -M $machine --no-pager -b 0 -o short-precise > /tmp/" . $machine . "_journal.log");
    upload_logs "/tmp/" . $machine . "_journal.log";
}

=head2 post_fail_hook

 post_fail_hook();

Upload the logs of all known containers.

=cut
sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');

    my $machines = script_output("machinectl --no-legend --no-pager | cut -d ' ' -f 1");
    foreach my $machine (split(/\s|\n/, $machines)) {
        $machine =~ s/\s|\n//g;
        if ($machine ne "") {
            $self->export_container_journal($machine);
        }
    }

    $self->SUPER::post_fail_hook;
}

1;
