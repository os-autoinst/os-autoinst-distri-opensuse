# SUSE's openQA tests
#
# Copyright 2019-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: systemd udev util-linux e2fsprogs
# Summary: Check udev persistent storage links (/dev/disk/by-*)
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

my $rules = '/usr/lib/udev/rules.d/60-persistent-storage.rules';

sub settle {
    assert_script_run('udevadm settle --timeout=60', timeout => 90);
}

# Poll a shell condition for up to 10 seconds, udev handles events asynchronously
sub wait_until {
    my ($cond, $what) = @_;
    my $ret = script_run("for i in \$(seq 1 20); do $cond && break; sleep 0.5; done; $cond", timeout => 30);
    die "Timed out waiting for: $what" if $ret;
}

sub wait_link {
    my ($link, $target) = @_;
    my $ret = script_run(qq{for i in \$(seq 1 20); do [ "\$(readlink -f '$link')" = '$target' ] && break; sleep 0.5; done; [ "\$(readlink -f '$link')" = '$target' ]}, timeout => 30);
    return unless $ret;
    my $actual = script_output("readlink -f '$link' || echo '<missing>'", proceed_on_failure => 1);
    die "$link should point to $target, but points to $actual";
}

sub wait_no_link {
    my ($link) = @_;
    wait_until("! [ -e '$link' -o -L '$link' ]", "$link to be removed");
}

sub wait_part_nodes {
    my ($dev, @nums) = @_;
    settle;
    wait_until("[ -b $dev$_ ]", "$dev$_ to appear") foreach @nums;
}

sub blkid_value {
    my ($dev, $tag) = @_;
    return script_output("blkid -p -s $tag -o value $dev");
}

# Links resolving to $target, or with $prefix also to its partitions
sub links_to {
    my ($target, $prefix) = @_;
    my $pattern = $prefix ? "$target*" : $target;
    my $out = script_output(qq{find /dev/disk -type l | while read l; do case "\$(readlink -f "\$l")" in $pattern) echo "\$l";; esac; done; true});
    return grep { length } split(/\n/, $out);
}

sub load_scsi_debug {
    my ($self, $size_mb) = @_;
    die 'scsi_debug is already loaded, refusing to reuse it' unless script_run('lsmod | grep -q "^scsi_debug "');
    assert_script_run("modprobe scsi_debug dev_size_mb=$size_mb");
    $self->{scsi_debug} = 1;
    settle;
    my @disks = grep { length } split(/\n/, script_output(q{for b in /sys/block/sd*; do [ "$(tr -d ' ' < $b/device/model 2>/dev/null)" = scsi_debug ] && basename $b; done; true}));
    die 'Expected exactly one scsi_debug disk, found: ' . join(' ', @disks) unless @disks == 1;
    record_info('scsi_debug', "Using /dev/$disks[0]");
    return "/dev/$disks[0]";
}

sub unload_scsi_debug {
    my ($self, $dev) = @_;
    my @links = links_to($dev, 1);
    die "No links found for $dev before removal" unless @links;
    settle;
    assert_script_run('modprobe -r scsi_debug');
    $self->{scsi_debug} = 0;
    settle;
    wait_no_link($_) foreach @links;
    record_info('Removal', scalar(@links) . " links of $dev removed");
}

sub verify_rules {
    if (script_run('udevadm verify --help > /dev/null 2>&1')) {
        record_info('Skip verify', 'udevadm verify is not available (udev < 254)');
        return;
    }
    assert_script_run('udevadm verify', timeout => 120);
}

# scsi_debug has no by-path links (path_id does not handle its pseudo bus),
# so check them read-only on the first real disk that has an ID_PATH
sub check_by_path {
    my $disks = script_output(q{lsblk -dnpo NAME,TYPE | awk '$2 == "disk" {print $1}'});
    my ($dev, $id_path);
    foreach my $d (split(/\n/, $disks)) {
        $id_path = script_output("udevadm info -q property -n $d | sed -n 's/^ID_PATH=//p'");
        if ($id_path) { $dev = $d; last; }
    }
    unless ($dev) {
        record_info('Skip by-path', 'No disk with ID_PATH found');
        return;
    }
    my $name = $dev =~ s{^/dev/}{}r;
    wait_link("/dev/disk/by-path/$id_path", $dev);
    my $partnum = !script_run("grep -q by-partnum $rules");
    my $parts = script_output("for p in /sys/block/$name/$name*/partition; do [ -f \$p ] && echo \$(basename \$(dirname \$p)) \$(cat \$p); done; true");
    foreach my $line (split(/\n/, $parts)) {
        my ($part, $num) = split(' ', $line);
        wait_link("/dev/disk/by-path/$id_path-part$num", "/dev/$part");
        wait_link("/dev/disk/by-path/$id_path-part/by-partnum/$num", "/dev/$part") if $partnum;
    }
    record_info('by-path', "Checked $dev ($id_path)" . ($partnum ? ', including -part/by-partnum' : ''));
}

sub check_part_links {
    my ($dev, $num, $has_fs) = @_;
    my $part = "$dev$num";
    wait_link('/dev/disk/by-partlabel/' . blkid_value($part, 'PART_ENTRY_NAME'), $part);
    wait_link('/dev/disk/by-partuuid/' . blkid_value($part, 'PART_ENTRY_UUID'), $part);
    return unless $has_fs;
    wait_link('/dev/disk/by-uuid/' . blkid_value($part, 'UUID'), $part);
    wait_link('/dev/disk/by-label/' . blkid_value($part, 'LABEL'), $part);
}

sub check_disk_links {
    my ($dev, @nums) = @_;
    my $name = $dev =~ s{^/dev/}{}r;
    my @ids = grep { m{/by-id/} } links_to($dev);
    die "No by-id links for $dev" unless @ids;
    foreach my $id (@ids) {
        wait_link("$id-part$_", "$dev$_") foreach @nums;
    }
    return if script_run("[ -f /sys/block/$name/diskseq ]");
    my $seq = script_output("cat /sys/block/$name/diskseq");
    wait_link("/dev/disk/by-diskseq/$seq", $dev);
    wait_link("/dev/disk/by-diskseq/$seq-part$_", "$dev$_") foreach @nums;
}

sub test_links {
    my ($self) = @_;
    my $dev = $self->load_scsi_debug(64);

    assert_script_run(qq{printf 'label: gpt\\nsize=16MiB, name=qa_alpha\\nsize=16MiB, name=qa_beta\\nsize=16MiB, name=qa_gamma\\n' | sfdisk -q $dev});
    wait_part_nodes($dev, 1 .. 3);
    assert_script_run("mkfs.ext4 -q -F -L qa_fs_alpha ${dev}1");
    assert_script_run("mkfs.ext4 -q -F -L qa_fs_beta ${dev}2");
    settle;

    check_disk_links($dev, 1 .. 3);
    check_part_links($dev, 1, 1);
    check_part_links($dev, 2, 1);
    check_part_links($dev, 3, 0);
    record_info('Links', 'All by-id, by-diskseq, by-partlabel, by-partuuid, by-uuid and by-label links are correct');

    # Renaming a partition or relabeling a filesystem must update the links
    # through udev's inotify watch, without a manual trigger
    assert_script_run("sfdisk -q --part-label $dev 3 qa_delta");
    wait_part_nodes($dev, 1 .. 3);
    wait_link('/dev/disk/by-partlabel/qa_delta', "${dev}3");
    wait_no_link('/dev/disk/by-partlabel/qa_gamma');
    assert_script_run("e2label ${dev}1 qa_fs_omega");
    wait_link('/dev/disk/by-label/qa_fs_omega', "${dev}1");
    wait_no_link('/dev/disk/by-label/qa_fs_alpha');
    record_info('Change', 'Links follow partition and filesystem label changes');

    # With two partitions sharing a name the link must point to one of them,
    # and move to the other one when that partition goes away
    assert_script_run("sfdisk -q --part-label $dev 2 qa_alpha");
    wait_part_nodes($dev, 1 .. 3);
    wait_until("readlink -f /dev/disk/by-partlabel/qa_alpha | grep -qE '^${dev}[12]\$'", 'qa_alpha to point to partition 1 or 2');
    my ($owner) = script_output('readlink -f /dev/disk/by-partlabel/qa_alpha') =~ /(\d+)$/;
    my $other = $owner == 1 ? 2 : 1;
    assert_script_run("sfdisk -q --delete $dev $owner");
    wait_part_nodes($dev, $other, 3);
    wait_link('/dev/disk/by-partlabel/qa_alpha', "$dev$other");
    record_info('Duplicate', "qa_alpha moved from partition $owner to $other");

    $self->unload_scsi_debug($dev);
}

# SLE 15 ships a workaround for bsc#1089761: no by-partlabel links for the
# generic "primary"/"logical" names, and a warning when 100+ partitions use them
sub test_partlabel_workaround {
    my ($self) = @_;
    if (script_run("grep -q 'primary|logical' $rules")) {
        record_info('Skip bsc#1089761', 'The primary/logical partlabel filter is not shipped on this product');
        return;
    }
    my $dev = $self->load_scsi_debug(128);
    assert_script_run("{ echo 'label: gpt'; for i in \$(seq 1 101); do echo 'size=1MiB, name=primary'; done; echo 'size=1MiB, name=qa_control'; } | sfdisk -q $dev", timeout => 120);
    wait_part_nodes($dev, 102);
    wait_link('/dev/disk/by-partlabel/qa_control', "${dev}102");
    assert_script_run('! [ -e /dev/disk/by-partlabel/primary ]', fail_message => 'by-partlabel link created for "primary"');
    my $unit = 'detect-part-label-duplicates.service';
    assert_script_run("systemctl restart $unit");
    assert_script_run("journalctl -b -u $unit --no-pager | grep 'Warning: a high number of partitions uses'");
    record_info('bsc#1089761', 'No links for "primary", warning shown for 101 partitions');
    $self->unload_scsi_debug($dev);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    record_info('udev', script_output('udevadm --version'));

    verify_rules;
    check_by_path;
    $self->test_links;
    $self->test_partlabel_workaround;
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    script_run('udevadm info --export-db > /tmp/udev-db.txt 2>&1');
    upload_logs('/tmp/udev-db.txt', failok => 1);
    script_run('modprobe -r scsi_debug') if $self->{scsi_debug};
}

1;

=head1 Description

Check that udev creates, updates and removes the persistent storage links in
C</dev/disk/by-*> correctly.

=over

=item * C<udevadm verify> checks the syntax of all installed udev rules
(udev 254+).

=item * The C<by-path> links, including C<by-path/*-part/by-partnum> where
the rules provide it, are checked read-only on the first disk that has an
C<ID_PATH>.

=item * A C<scsi_debug> RAM disk is partitioned with C<sfdisk> and two
partitions get an ext4 filesystem. The C<by-id>, C<by-diskseq>,
C<by-partlabel>, C<by-partuuid>, C<by-uuid> and C<by-label> links must point
to the partition that C<blkid -p> reports for each value.

=item * Renaming a partition and relabeling a filesystem must update the
links without a manual C<udevadm trigger>.

=item * With two partitions sharing a name, the C<by-partlabel> link must
point to one of them and move to the other when that partition is deleted.

=item * After unloading C<scsi_debug>, none of its links may remain.

=item * Only where the rules still filter the C<primary>/C<logical> partition
names (the SLE 15 workaround for bsc#1089761): 101 partitions named
C<primary> must not get a C<by-partlabel> link, and
C<detect-part-label-duplicates.service> must warn about them.

=back

=head1 Requirements

The C<scsi_debug> module must be available (it is part of C<kernel-default>,
not C<kernel-default-base>) and must not be in use already. No additional
disk is needed and the test does not reboot.

=cut
