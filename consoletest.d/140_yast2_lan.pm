use base "yasttest";
use bmwqemu;

# test yast2 lan functionality
# https://bugzilla.novell.com/show_bug.cgi?id=600576

sub run() {
    my $self = shift;
    script_sudo("/sbin/yast2 lan");

    my $ret = assert_screen [qw/Networkmanager_controlled yast2_lan/], 12;
    if($ret->{needle}->has_tag('Networkmanager_controlled')) {
      send_key "ret";      # confirm networkmanager popup
      assert_screen "Networkmanager_controlled-approved";
      send_key "alt-c";
      assert_screen 'yast2-lan-exited', 30;
      return; # don't change any settings
    }

    my $hostname = "susetest";
    my $domain   = "zq1.de";

    send_key "alt-s";       # open hostname tab
    assert_screen "yast2_lan-hostname-tab";
    send_key "tab";
    for ( 1 .. 15 ) { send_key "backspace" }
    type_string $hostname;
    send_key "tab";
    for ( 1 .. 15 ) { send_key "backspace" }
    type_string $domain;
    assert_screen 'test-yast2_lan-1', 8;

    send_key "alt-o";       # OK=>Save&Exit
    assert_screen 'yast2-lan-exited', 30;

    send_key "ctrl-l";      # clear screen
    script_run('echo $?');
    script_run('hostname');
    assert_screen 'test-yast2_lan-2', 3;

    send_key "ctrl-l";      # clear screen
    script_run('ip -o a s');
    script_run('ip r s');
    script_run('getent ahosts '.$vars{OPENQA_HOSTNAME});
    #
    script_run("echo \"EXIT-\$?\" > /dev/$serialdev");
    die unless wait_serial "EXIT-0", 2;
}

sub test_flags() {
    return { 'milestone' => 1, 'fatal' => 1 };
}

1;

# vim: set sw=4 et:
