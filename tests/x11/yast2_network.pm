use base "x11test";
use testapi;

# Helper method to enable routing through `lan` client.
sub enable_routing() {
  send_key "alt-u"; # Routing tab
  assert_screen "yast2_network-routing_disabled";
  send_key "alt-i"; # Activate IPv4 routing
  send_key "alt-p"; # Activate IPv6 routing
  assert_screen "yast2_network-routing_enabled";
}

# Helper method to check if routing is enabled.
sub check_routing_enabled_ui() {
    # Check at UI level
    send_key "alt-u"; # Routing
    assert_screen "yast2_network-rounting_enabled";
}

sub check_routing_enabled_console() {
    # Check at system level
    script_run "sysctl net.ipv4.conf.all.forwarding > /dev/$serialdev";
    wait_serial("net.ipv4.conf.all.forwarding = 1", 5) || die("IPv4 not enabled");
}

sub start_yast2_lan() {
    script_run "yast2 lan";
    assert_screen "yast2_network-lan", 50;
}

# Test for basic yast2-network functionality.
sub run() {
  my $self = shift;

  # Make sure yast2-network ins installed (if not, install it)
  ensure_installed "yast2-network";

  # Start xterm as root
  x11_start_program("xterm");
  wait_idle;
  become_root;

  # Make sure that firewall is running
  script_run "yast2 firewall enable";

  # Enable routing
  start_yast2_lan;
  enable_routing;

  # Save settings
  send_key "alt-o";
  wait_idle;

  # Stop firewall
  script_run "yast2 firewall disable";

  # Check that routing is still enabled
  check_routing_enabled_console;
  start_yast2_lan;
  check_routing_enabled_ui;

  # Exit
  send_key "alt-o";
  script_run "exit";
}

1;
# vim: set sw=4 et;
