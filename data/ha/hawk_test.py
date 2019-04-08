#!/usr/bin/python3
"""HAWK GUI interface Selenium test: tests hawk GUI with Selenium using firefox or chrome"""

import argparse, re, hawk_test_driver, hawk_test_ssh, hawk_test_results

### MAIN

# Command line argument parsing
parser = argparse.ArgumentParser(description='HAWK GUI interface Selenium test')
parser.add_argument('-b', '--browser', type=str, required=True,
                    help='Browser to use in the test. Can be: firefox, chrome, chromium')
parser.add_argument('-H', '--host', type=str, default='localhost',
                    help='Host or IP address where HAWK is running')
parser.add_argument('-P', '--port', type=str, default='7630',
                    help='TCP port where HAWK is running')
parser.add_argument('-p', '--prefix', type=str, default='',
                    help='Prefix to add to Resources created during the test')
parser.add_argument('-t', '--test-version', type=str, default='', required=True,
                    help='Test version. Ex: 12-SP3, 12-SP4, 15, 15-SP1')
parser.add_argument('-s', '--secret', type=str, default='',
                    help='root SSH Password of the HAWK node')
parser.add_argument('-r', '--results', type=str, default='',
                    help='Generate hawk_test.results file')
args = parser.parse_args()

# Create driver instance
browser = hawk_test_driver.hawkTestDriver(addr=args.host.lower(), port=args.port,
                                          browser=args.browser.lower(),
                                          version=args.test_version.lower())

# Initialize results set
results = hawk_test_results.resultSet()

# Establish SSH connection to verify status only if SSH password was supplied
if args.secret:
    ssh = hawk_test_ssh.hawkTestSSH(args.host.lower(), args.secret)
    results.add_ssh_tests()

# Resources to create
if args.prefix and not re.match(r"^\w+$", args.prefix.lower()):
    print("ERROR: Prefix must contain only numbers and letters. Ignoring")
    args.prefix = ''
mycluster = args.prefix.lower() + 'Anderes'
myprimitive = args.prefix.lower() + 'cool_primitive'
myclone = args.prefix.lower() + 'cool_clone'
mygroup = args.prefix.lower() + 'cool_group'

# Tests to perform
browser.test('test_set_stonith_maintenance', results)
if args.secret:
    ret = ssh.verify_stonith_in_maintenance(results)
    if ret != 0:
        browser.set_retval(ret)
browser.test('test_disable_stonith_maintenance', results)
browser.test('test_view_details_first_node', results)
browser.test('test_clear_state_first_node', results)
browser.test('test_set_first_node_maintenance', results)
if args.secret:
    ret = ssh.verify_node_maintenance(results)
    if ret != 0:
        browser.set_retval(ret)
browser.test('test_disable_maintenance_first_node', results)
browser.test('test_add_new_cluster', results, mycluster)
browser.test('test_remove_cluster', results, mycluster)
browser.test('test_click_on_history', results)
browser.test('test_generate_report', results)
browser.test('test_click_on_command_log', results)
browser.test('test_click_on_status', results)
browser.test('test_add_primitive', results, myprimitive)
if args.secret:
    ret = ssh.verify_primitive(myprimitive, args.test_version.lower(), results)
    if ret != 0:
        browser.set_reval(ret)
browser.test('test_remove_primitive', results, myprimitive)
if args.secret:
    ret = ssh.verify_primitive_removed(results)
    if ret != 0:
        browser.set_retval(ret)
browser.test('test_add_clone', results, myclone)
browser.test('test_remove_clone', results, myclone)
browser.test('test_add_group', results, mygroup)
browser.test('test_remove_group', results, mygroup)
browser.test('test_click_around_edit_conf', results)

# Save results if run with -r or --results
if args.results:
    results.logresults(args.results)

quit(browser.get_retval())
