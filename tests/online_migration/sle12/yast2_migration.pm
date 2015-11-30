use base "installbasetest";
use strict;
use testapi;

sub run {
    my $self = shift;
    script_run "yast2 migration";

    # ask installing update before migration if not perform full update for system
    if (!get_var("FULL_UPDATE_BEFORE_MIGRATION")) {
        assert_screen 'yast2-migration-onlineupdates', 10;
        send_key "alt-y";
        assert_screen 'yast2-migration-updatesoverview', 10;
        send_key "alt-a";
    }

    # wait for migration target after needed updates installed
    assert_screen 'yast2-migration-target', 300;
    send_key "alt-n";
    assert_screen 'yast2-migration-installupdate', 200;
    send_key "alt-y";
    assert_screen 'yast2-migration-proposal', 200;

    # disable installation repo
    assert_screen 'recommend-to-disable', 5;
    send_key "tab";
    send_key_until_needlematch 'disable-repo', 'down', 3;
    send_key "ret", 1;

    send_key "alt-n";
    assert_screen 'yast2-migration-startupgrade', 10;
    send_key "alt-u";
    assert_screen "yast2-migration-upgrading", 30;

    # start migration
    my @tags    = qw/yast2-migration-wrongdigest yast2-migration-packagebroken yast2-migration-internal-error yast2-migration-finish/;
    my $timeout = 5000;
    while (1) {
        my $ret = check_screen \@tags, $timeout;
        if ($ret->{needle}->has_tag("yast2-migration-internal-error")) {
            $self->result('fail');
            send_key "alt-o";
            save_screenshot;
            return;
        }
        elsif ($ret->{needle}->has_tag("yast2-migration-packagebroken")) {
            $self->result('fail');
            send_key "alt-d";
            save_screenshot;
            send_key "alt-s";
            return;
        }
        elsif ($ret->{needle}->has_tag("yast2-migration-wrongdigest")) {
            $self->result('fail');
            send_key "alt-a", 1;
            save_screenshot;
            send_key "alt-n";
            return;
        }
        last if $ret->{needle}->has_tag("yast2-migration-finish");
    }
    assert_screen 'yast2-migration-finish';
    send_key "alt-f";

    # after migration yast may ask to reboot system
    if (check_screen("yast2-ask-reboot", 5)) {
        send_key "alt-c";    # cancel it and reboot in post migration step
    }
}

sub test_flags() {
    return {'fatal' => 1, 'important' => 1};
}

1;
# vim: set sw=4 et:
