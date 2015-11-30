use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # precompile regexes
    my $zypper_migration_target = qr/\[num\/q\]/m;
    my $zypper_disable_repos = qr/^Disable obsolete repository/m;
    my $zypper_migraiton_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_migration_error = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_migration_fileconflict = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_migration_done = qr/^Executing.*after online migration|^ZYPPER-DONE/m;
    my $zypper_continue = qr/^Continue\? \[y/m;
    my $zypper_finish = qr/^There are some running programs that might use files|^ZYPPER-DONE/m;

    # start migration
    script_run ("(zypper migration;echo ZYPPER-DONE) | tee /dev/$serialdev");
    my $out = wait_serial([$zypper_migration_target, $zypper_disable_repos, $zypper_continue, $zypper_migration_done, $zypper_migration_error, $zypper_migraiton_conflict, $zypper_migration_fileconflict], 5000);
    while ($out) {
        if ($out =~ $zypper_migration_target) {
            send_key "1", 1;
            send_key "ret";
        }
        elsif ($out =~ $zypper_disable_repos) {
            send_key "y", 1;
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_error || $out =~ $zypper_migraiton_conflict || $out =~ $zypper_migration_fileconflict) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_continue) {
            send_key "y", 1;
            send_key "ret";
        }
        elsif ($out =~ $zypper_migration_done) {
            last;
        }
        $out = wait_serial([$zypper_migration_target, $zypper_disable_repos, $zypper_continue, $zypper_migration_done, $zypper_migration_error, $zypper_migraiton_conflict, $zypper_migration_fileconflict], 5000);
    }
}

sub test_flags() {
    return {'fatal' => 1, 'important' => 1};
}

1;
# vim: set sw=4 et:
