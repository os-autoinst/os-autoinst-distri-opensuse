use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # precompile regexes
    my $zypper_dup_continue = qr/^Continue\? \[y/m;
    my $zypper_dup_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_dup_notifications = qr/^View the notifications now\? \[y/m;
    my $zypper_dup_error = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_dup_finish = qr/^There are some running programs that might use files|^ZYPPER-DONE/m;
    my $zypper_packagekit = qr/^Tell PackageKit to quit\?/m;
    my $zypper_packagekit_again = qr/^Try again\?/m;
    my $zypper_repo_disabled = qr/^Repository '\S+' has been successfully disabled./m;
    my $zypper_installing = qr/Installing: \S+/;

    # Disable all repos, so we do not need to remove one by one
    # beware PackageKit!
    script_run("zypper modifyrepo --all --disable | tee /dev/$serialdev");
    my $out = wait_serial([$zypper_packagekit, $zypper_repo_disabled], 120);
    while($out) {
        if ($out =~ $zypper_packagekit || $out =~ $zypper_packagekit_again) {
            send_key 'y';
            send_key 'ret';
        }
        elsif ($out =~ $zypper_repo_disabled) {
            last;
        }
        $out = wait_serial([$zypper_repo_disabled, $zypper_packagekit_again, $zypper_packagekit], 120);
    }
    unless ($out) {
        save_screenshot;
        $self->result('fail');
        return;
    }

    my $defaultrepo;
    if (get_var('SUSEMIRROR')) {
        $defaultrepo = "http://" . get_var("SUSEMIRROR");
    }
    else {
        # SUSEMIRROR not set, zdup from attached ISO
        $defaultrepo = 'dvd:///';
    }

    my $nr = 1;
    foreach my $r ( split( /\+/, get_var("ZDUPREPOS", $defaultrepo) ) ) {
        script_run("zypper addrepo $r repo$nr");
        $nr++;
    }
    script_run("zypper --gpg-auto-import-keys refresh");

    script_run("(zypper dup -l;echo ZYPPER-DONE) | tee /dev/$serialdev");

    $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 240);
    while($out) {
        if ($out =~ $zypper_dup_conflict) {
            send_key '1', 1;
            send_key 'ret', 1;
        }
        elsif ($out =~ $zypper_dup_continue) {
            save_screenshot;
            # confirm zypper dup continue
            send_key 'y', 1;
            send_key 'ret', 1;
            last;
        }
        elsif ($out =~ $zypper_dup_error) {
            save_screenshot;
            $self->result('fail');
            return;
        }
        $out = wait_serial([$zypper_dup_continue, $zypper_dup_conflict, $zypper_dup_error], 120);
    }
    unless($out) {
        save_screenshot;
        $self->result('fail');
        return;
    }

    # wait for zypper dup finish, accept failures in meantime
    $out = wait_serial([$zypper_dup_finish, $zypper_installing, $zypper_dup_notifications, $zypper_dup_error], 240);
    while ($out) {
        if ($out =~ $zypper_dup_notifications) {
            send_key 'n', 1; # do not show notifications
            send_key 'ret', 1;
        }
        elsif ($out =~ $zypper_dup_error) {
            $self->result('fail');
            save_screenshot;
            return;
        }
        elsif ($out =~ $zypper_dup_finish) {
            last;
        }
        else {
            # probably to avoid hitting black screen on video
            send_key 'shift', 1;
        }
        $out = wait_serial([$zypper_dup_finish, $zypper_installing, $zypper_dup_notifications, $zypper_dup_error], 240);
    }

    assert_screen "zypper-dup-finish", 2;
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
