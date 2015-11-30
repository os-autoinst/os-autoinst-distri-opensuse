use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self    = shift;
    my $result  = 'ok';
    my $datamax = get_var("BTRFS_MAXDATASIZE");

    script_run "echo btrfs-data=\$(btrfs filesystem df -b / | grep Data | sed -n -e 's/^.*used=//p') | tee -a /dev/$serialdev";    # spit out only the part of the btrfs filesystem size we're interested in
    my $datasize = wait_serial('btrfs-data=\d+\S+');                                                                               # https://xkcd.com/208/
    die "failed to get btrfs-data size" unless (defined $datasize);                                                                # shouldn't ever happen, bet just incase it does
    $datasize = substr $datasize, 11;

    if ($datasize > $datamax) {
        $result = 'fail';
    }
    $self->result($result);
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
