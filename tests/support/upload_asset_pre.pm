use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # switch to console
    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    type_password;
    type_string "\n";
    sleep 1;
    save_screenshot;

    # create a verify file to etc/ and add a TAG to it
    # ie. the final uploaded asset name
    my $asset_id;

    if ( get_var("STORE_HDD_1") ) {
        my $jobid;
        my $jobname = get_var("NAME");
        if ( $jobname =~ /^(\d{8})-/ ) {
            $jobid = $1;
        }
        else {
            die "can not find valid jobid from $jobname";
        }
        $asset_id = $jobid . "-" . get_var("STORE_HDD_1");
    }
    elsif ( get_var("PUBLISH_HDD_1") ) {
        $asset_id = get_var("PUBLISH_HDD_1");
    }

    script_run "echo $asset_id > /etc/OPENQA_ASSET_TAG";
    script_run "cat /etc/OPENQA_ASSET_TAG";
    save_screenshot;

    # switch to X
    send_key "ctrl-alt-f7";
    wait_idle;
    save_screenshot;
}

1;
# vim: set sw=4 et:
