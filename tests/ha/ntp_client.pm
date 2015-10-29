use base "hacluster";
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    script_run("yast2 ntp-client");
    assert_screen "yast2-ntp-client", 30;
    send_key 'alt-b'; #start ntp daemon on Boot
    send_key 'alt-a'; #add new Server
    assert_screen "yast2-ntp-client-add-source", 30;
    send_key 'alt-n'; #Next
    assert_screen "yast2-ntp-client-add-server", 30;
    type_string "ntp";
    send_key 'alt-o'; #Ok
    assert_screen "yast2-ntp-client-server-list";
    send_key 'alt-o'; #Ok
    script_run "echo \"ntpcount=`ntpq -p | tail -n +3 | wc -l`\"";
    script_run "echo \"ntpcount=`ntpq -p | tail -n +3 | wc -l`\" > /dev/$serialdev";
    die "Adding NTP servers failed" unless wait_serial "ntpcount=1";
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
