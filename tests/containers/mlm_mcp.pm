use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::k8s;

sub run {
    select_serial_terminal;

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');

    script_retry("podman pull $image", timeout => 300, delay => 60, retry => 3);

    # JSON-RPC payloads for MCP stdio initialization handshake and tool discovery
    my $init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}}}';
    my $initialized = '{"jsonrpc":"2.0","method":"notifications/initialized"}';
    my $tools_list = '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}';

    # Multi Linux Manager (Uyuni) requires basic configuration values to boot
    my $env_flags = '-e UYUNI_SERVER=dummy -e UYUNI_USER=user -e UYUNI_PASS=pass';

    # Send sequence through interactive stdin (-i) and auto-remove after execution (--rm)
    my $mcp_cmd = "{ printf '%s\\n' '$init' '$initialized' '$tools_list'; sleep 2; } | podman run -i --rm $env_flags $image";

    # Assert that the container successfully responds with its registered MCP tools
    assert_script_run("$mcp_cmd", timeout => 200);
    assert_script_run("$mcp_cmd | grep 'list_systems'", timeout => 200);
}

1;
