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

use base 'consoletest';
use utils 'systemctl';
use testapi qw(assert_script_run upload_logs type_string);

sub assert_script_run_container {
    my ($self, $machine, $script) = @_;
    assert_script_run("systemd-run -tM $machine /bin/bash -c \"$script\"");
}

sub start_nspawn_container {
    my ($self, $machine) = @_;
    assert_script_run("systemctl start systemd-nspawn-openqa@".$machine);
}

sub setup_nspawn_container {
    my ($self, $machine, $repo, $packages) = @_;
    my $path = "/var/lib/machines/$machine";
    assert_script_run("mkdir $path");
    assert_script_run("zypper -n --root $path --gpg-auto-import-keys addrepo $repo defaultrepo");
    # handle zypper 'warning' return codes > 100 gracefully
    assert_script_run("zypper -n --root $path install --no-recommends -ly $packages ; [[ \$? == 0 || \$? -gt 99 ]]");
}


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

sub write_container_file {
    my ($self, $machine, $file, $content) = @_;
    my $path = "/var/lib/machines/$machine/$file";
    $self->write_file($path, $content);
}

sub write_file {
    my ($self, $file, $content) = @_;
    type_string("cat > $file <<EOF\n$content\nEOF\n");
    sleep 1;
    assert_script_run("test \$? == 0");
}

1;
