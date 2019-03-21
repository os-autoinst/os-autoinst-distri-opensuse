#!/usr/bin/python3
"""HAWK GUI interface Selenium test: tests hawk GUI with Selenium using firefox or chrome"""

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from distutils.version import LooseVersion as Version
import time, argparse, re, json, paramiko, warnings
# Ignore CryptographyDeprecationWarning shown when using paramiko
try:
    from cryptography.utils import CryptographyDeprecationWarning
    warnings.simplefilter('ignore', CryptographyDeprecationWarning)
except ImportError:
    pass

# Global return value, set by the functions and returned by main()
RETURN_VALUE = 0

# Global value for tests and results
RESULTS_SET = {'tests': [], 'info': {}, 'summary': {}}
MY_TESTS = ['hawk_log_in', 'set_stonith_maintenance', 'disable_stonith_maintenance',
            'view_details_first_node', 'clear_state_first_node', 'set_first_node_maintenance',
            'disable_maintenance_first_node', 'add_new_cluster', 'remove_cluster',
            'test_click_on_history', 'generate_report', 'test_click_on_command_log',
            'test_click_on_status', 'add_primitive', 'remove_primitive', 'add_clone',
            'remove_clone', 'add_group', 'remove_group', 'click_around_edit_conf']

# XPATH constants
CLICK_OK_SUBMIT = "//*[@id=\"modal\"]/div/div/form/div[3]/input"
CONFIG_EDIT = '//a[contains(@href, "config/edit")]'
OCF_OPT_LIST = '//option[contains(@value, "ocf")]'
ANYTHING_OPT_LIST = '//option[contains(@value, "anything")]'
EDIT_START_TIMEOUT = "//*[@id=\"oplist\"]/fieldset/div/div[1]/div[1]/div[2]/div/div/a[1]"
EDIT_STOP_TIMEOUT = "//*[@id=\"oplist\"]/fieldset/div/div[1]/div[2]/div[2]/div/div/a[1]"
MODAL_TIMEOUT = "//*[@id=\"modal\"]/div/div/form/div[2]/fieldset/div/div[1]/div/div"
MODAL_STOP = "//*[@id=\"modal\"]/div/div/form/div[2]/fieldset/div/div[2]/div/div/select/option[6]"
EDIT_MONITOR_TIMEOUT = "//*[@id=\"oplist\"]/fieldset/div/div[1]/div[3]/div[2]/div/div/a[1]"
MODAL_MONITOR_TIMEOUT = "//*[@id=\"modal\"]/div/div/form/div[2]/fieldset/div/div[1]/div"
TARGET_ROLE_STARTED = '//option[contains(@value, "tarted")]'
HREF_DELETE_FORMAT = '//a[contains(@href, "%s") and contains(@title, "Delete")]'
COMMIT_BTN_DANGER = '//button[contains(@class, "btn-danger") and contains(@class, "commit")]'
CLONE_DATA_HELP_FILTER = '//a[contains(@data-help-filter, ".clone")]'
OPT_STONITH = '//option[contains(@value, "stonith-sbd")]'
RSC_OK_SUBMIT = '//input[contains(@class, "submit")]'
GROUP_DATA_FILTER = '//a[contains(@data-help-filter, ".group")]'
STONITH_CHKBOX = '//input[contains(@type, "checkbox") and contains(@value, "stonith-sbd")]'
HREF_CONSTRAINTS = '//a[contains(@href, "#constraints")]'
HREF_NODES = '//a[contains(@href, "#nodes")]'
HREF_TAGS = '//a[contains(@href, "#tags")]'
HREF_ALERTS = '//a[contains(@href, "#alerts")]'
HREF_FENCING = '//a[contains(@href, "#fencing")]'
RSC_ROWS = "//*[@id=\"resources\"]/div[1]/div[2]/div[2]/table/tbody/tr"
DROP_DOWN_FORMAT = "//*[@id=\"resources\"]/div[1]/div[2]/div[2]/table/tbody/tr[%d]/td[6]/div/div"
STONITH_MAINT_ON = '//a[contains(@href, "stonith-sbd/maintenance_on")]'
NODE_DETAILS = "//*[@id=\"nodes\"]/div[1]/div[2]/div[2]/table/tbody/tr[1]/td[5]/div/a[2]"
DISMISS_MODAL = "//*[@id=\"modal\"]/div/div/div[3]/button"
CLEAR_STATE = "//*[@id=\"nodes\"]/div[1]/div[2]/div[2]/table/tbody/tr[1]/td[5]/div/div/button"
NODE_MAINT = '//a[contains(@href, "maintenance") and contains(@title, "Switch to maintenance")]'
NODE_READY = '//a[contains(@href, "ready") and contains(@title, "Switch to ready")]'
GENERATE_REPORT = "//*[@id=\"generate\"]/form/div/div[2]/button"
CLONE_CHILD = ('//select[contains(@data-help-filter, ".row.resource") and '
               'contains(@name, "clone[child]")]')
TARGET_ROLE_FORMAT = ('//select[contains(@class, "form-control") and '
                      'contains(@name, "%s[meta][target-role]")]')
STONITH_MAINT_OFF = ('//a[contains(@href, "stonith-sbd") and '
                     'contains(@title, "Disable Maintenance Mode")]')

# Functions

### Functions to check types and classes

def checkint(i):
    if isinstance(i, int):
        return i
    else:
        # Default to 1 if no int argument
        return 1

def checkstr(s):
    if isinstance(s, str):
        return s
    else:
        return str(s)

def is_driver(d):
    clase = str(type(d)).split(' ')[1][1:19]
    if clase != 'selenium.webdriver':
        print('ERROR: Driver must be of type webdriver. Got: [%s]' % type(d))
        return False
    return True

def is_ssh(s):
    clase = str(type(s)).split(' ')[1][1:26]
    if clase != 'paramiko.client.SSHClient':
        print('ERROR: SSH object must be of type paramiko.client.SSHClient. Got: [%s]' % type(s))
        return False
    return True

### Logging and results

def logresults(filename):
    with open(filename, "w") as resfh:
        resfh.write(json.dumps(RESULTS_SET))

def set_test_status(testname, status):
    status = checkstr(status)
    testname = checkstr(testname)
    if status not in ['passed', 'failed']:
        print('ERROR: test status must be either [passed] or [failed]')
        return
    if (status.lower() == 'passed' and
            RESULTS_SET['tests'][MY_TESTS.index(testname)]['outcome'] != 'passed'):
        RESULTS_SET['summary']['passed'] += 1
    elif (status.lower() == 'failed' and
          RESULTS_SET['tests'][MY_TESTS.index(testname)]['outcome'] != 'failed'):
        RESULTS_SET['summary']['passed'] -= 1
    RESULTS_SET['tests'][MY_TESTS.index(testname)]['outcome'] = status.lower()
    RESULTS_SET['summary']['duration'] = time.process_time()
    RESULTS_SET['info']['timestamp'] = time.time()

def initialize_result_set(test_version, browser):
    if Version(checkstr(test_version)) < Version('15') and str(browser) == 'firefox':
        MY_TESTS.remove('test_click_on_history')
        MY_TESTS.remove('generate_report')
    for test in MY_TESTS:
        auxd = {'name': test, 'test_index': 0, 'outcome': 'failed'}
        RESULTS_SET['tests'].append(auxd)
    RESULTS_SET['info']['timestamp'] = time.time()
    with open('/etc/os-release', 'r') as fh:
        osrel = fh.read()
    RESULTS_SET['info']['distro'] = str(osrel[osrel.find('ID=')+3:osrel.find('ID_LIKE=')-1])
    RESULTS_SET['info']['results_file'] = 'hawk_test.results'
    RESULTS_SET['summary']['duration'] = 0
    RESULTS_SET['summary']['passed'] = 0
    RESULTS_SET['summary']['num_tests'] = len(MY_TESTS)

### Selenium helper functions

def find_element(browser, bywhat, texto, tout=60):
    tout = checkint(tout)
    if is_driver(browser):
        try:
            elem = WebDriverWait(browser,
                                 tout).until(EC.presence_of_element_located((bywhat, str(texto))))
        except TimeoutException:
            print("INFO: %d seconds timeout while looking for element [%s] by [%s]" %
                  (tout, texto, bywhat))
            return False
        return elem
    else:
        return False

def test_click_on(browser, text, timeout_scale, *testname):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    print("TEST: Main page. Click on %s" % text)
    time.sleep(5*timeout_scale)
    if is_driver(browser):
        elem = find_element(browser, By.PARTIAL_LINK_TEXT, str(text))
        if not elem:
            print("ERROR: Couldn't find element '%s'" % text)
            RETURN_VALUE = 6
        else:
            elem.click()
            if testname:
                set_test_status(str(testname[0]), 'passed')
    time.sleep(timeout_scale)

def verify_success(browser):
    if is_driver(browser):
        elem = find_element(browser, By.CLASS_NAME, 'alert-success', 60)
        if not elem:
            elem = find_element(browser, By.PARTIAL_LINK_TEXT, 'Rename', 5)
            if not elem:
                return False
        return True
    return False

# Some links by text are capitalized differently between the chrome and firefox drivers.
# Will get the browser type from the driver and then chose the appropiate text
def link_by_browser(browser, linktext):
    browser_type = (str(type(browser)).split(' ')[1]).split('.')[2]
    if browser_type == 'chrome':
        return str(linktext).upper()
    else:
        return str(linktext).capitalize()

def fill_value(browser, field, tout):
    global RETURN_VALUE
    elem = find_element(browser, By.NAME, str(field))
    if not elem:
        print("ERROR: couldn't find element [%s]." % str(field))
        RETURN_VALUE = 10
        return
    elem.clear()
    elem.send_keys(str(tout) + "s")

def submit_operation_params(browser, timeout_scale, retval, errmsg):
    check_and_click_by_xpath(browser, timeout_scale, int(retval), str(errmsg), [CLICK_OK_SUBMIT])

def check_edit_conf(browser, timeout_scale, version):
    print("TEST: Check edit configuration")
    click_if_major_version(browser, version, "14",
                           link_by_browser(browser, 'configuration'), timeout_scale)
    click_if_major_version(browser, version, "14", 'Edit Configuration', timeout_scale)
    check_and_click_by_xpath(browser, timeout_scale, 13, "Couldn't find Edit Configuration element",
                             [CONFIG_EDIT])

def check_and_click_by_xpath(browser, timeout_scale, retcode, errmsg, xpath_exps):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    retcode = checkint(retcode)
    if not isinstance(xpath_exps, list):
        print("ERROR: check_and_click_by_xpath requires a list of xpath strings. Got [%s]" %
              type(xpath_exps))
        RETURN_VALUE = retcode
        return
    if is_driver(browser):
        for e in xpath_exps:
            elem = find_element(browser, By.XPATH, str(e))
            if not elem:
                print("ERROR: Couldn't find element by xpath [%s] %s" % (e, errmsg))
                RETURN_VALUE = retcode
                return
            elem.click()
            time.sleep(2*timeout_scale)

# Clicks on element identified by clicker if major version from the test is greater or
# equal than the version to check
def click_if_major_version(browser, test_version, version_to_check, clicker, timeout_scale):
    if Version(str(test_version)) >= Version(str(version_to_check)):
        test_click_on(browser, clicker, timeout_scale)
        time.sleep(timeout_scale)

### Selenium tests

def hawk_log_in(browser):
    print("TEST: Log in into HAWK")
    if is_driver(browser):
        elem = find_element(browser, By.NAME, "session[username]")
        if not elem:
            print("ERROR: couldn't find element [session[username]]. Cannot login")
            browser.quit()
            quit(4)
        elem.clear()
        elem.send_keys("hacluster")
        elem = find_element(browser, By.NAME, "session[password]")
        if not elem:
            print("ERROR: Couldn't find element [session[password]]. Cannot login")
            browser.quit()
            quit(5)
        elem.send_keys("linux")
        elem.send_keys(Keys.RETURN)
    set_test_status('hawk_log_in', 'passed')

def add_new_cluster(browser, cluster_name, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    # First click on Dashboard
    test_click_on(browser, 'Dashboard', timeout_scale)
    time.sleep(2*timeout_scale)
    print("TEST: Add new cluster")
    if is_driver(browser):
        elem = find_element(browser, By.CLASS_NAME, "btn-default")
        if not elem:
            print("ERROR: Couldn't find class 'btn-default'")
            RETURN_VALUE = 7
            return
        elem.click()
        elem = find_element(browser, By.NAME, "cluster[name]")
        if not elem:
            print("ERROR: Couldn't find element [cluster[name]]. Cannot add cluster")
            RETURN_VALUE = 7
            return
        elem.send_keys(str(cluster_name))
        time.sleep(timeout_scale)
        elem = find_element(browser, By.NAME, "cluster[host]")
        if not elem:
            print("ERROR: Couldn't find element [cluster[host]]. Cannot add cluster")
            RETURN_VALUE = 7
            return
        elem.send_keys(args.host.lower())
        time.sleep(timeout_scale)
        elem = find_element(browser, By.NAME, "submit")
        if not elem:
            print("ERROR: Couldn't find submit button")
            RETURN_VALUE = 7
            return
        elem.click()
        while True:
            elem = find_element(browser, By.PARTIAL_LINK_TEXT, 'Dashboard')
            try:
                elem.click()
                set_test_status('add_new_cluster', 'passed')
                break
            except WebDriverException:
                time.sleep(1+timeout_scale)

def remove_cluster(browser, cluster_name, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    # First click on Dashboard
    test_click_on(browser, 'Dashboard', timeout_scale)
    time.sleep(2*timeout_scale)
    print("TEST: Remove cluster")
    if is_driver(browser):
        elem = find_element(browser, By.PARTIAL_LINK_TEXT, str(cluster_name))
        if not elem:
            print("ERROR: Couldn't find cluster [%s]. Cannot remove" % cluster_name)
            RETURN_VALUE = 8
            return
        elem.click()
        time.sleep(2*timeout_scale)
        elem = find_element(browser, By.CLASS_NAME, 'close')
        if not elem:
            print("ERROR: Cannot find cluster remove button")
            RETURN_VALUE = 8
            return
        elem.click()
        time.sleep(2*timeout_scale)
        elem = find_element(browser, By.CLASS_NAME, 'cancel')
        if not elem:
            print("ERROR: No cancel button while removing cluster [%s]" % cluster_name)
            RETURN_VALUE = 9
        else:
            elem.click()
        time.sleep(timeout_scale)
        elem = find_element(browser, By.CLASS_NAME, 'close')
        elem.click()
        time.sleep(2*timeout_scale)
        elem = find_element(browser, By.CLASS_NAME, 'btn-danger')
        if not elem:
            print("ERROR: No OK button found while removing cluster [%s]" % cluster_name)
            RETURN_VALUE = 8
        else:
            elem.click()
        if verify_success(browser):
            print("INFO: Successfully removed cluster: [%s]" % cluster_name)
            set_test_status('remove_cluster', 'passed')
        else:
            print("ERROR: Could not remove cluster [%s]" % cluster_name)
            RETURN_VALUE = 8

def add_primitive(browser, priminame, timeout_scale, version):
    global RETURN_VALUE
    priminame = checkstr(priminame)
    timeout_scale = checkint(timeout_scale)
    print("TEST: Add Resources: Primitive %s" % priminame)
    if is_driver(browser):
        click_if_major_version(browser, version, "15", link_by_browser(browser, 'configuration'),
                               timeout_scale)
        test_click_on(browser, 'Resource', timeout_scale)
        time.sleep(2*timeout_scale)
        test_click_on(browser, 'rimitive', timeout_scale)
        time.sleep(2*timeout_scale)
        # Fill the primitive
        elem = find_element(browser, By.NAME, 'primitive[id]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[id]]. Cannot add primitive [%s]." %
                  priminame)
            RETURN_VALUE = 10
            return
        elem.send_keys(str(priminame))
        time.sleep(timeout_scale)
        elem = find_element(browser, By.NAME, 'primitive[clazz]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[clazz]]. Cannot add primitive [%s]." %
                  priminame)
            RETURN_VALUE = 10
            return
        elem.click()
        time.sleep(timeout_scale)
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't find value [ocf] for primitive class",
                                 [OCF_OPT_LIST])
        elem = find_element(browser, By.NAME, 'primitive[type]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[type]]. Cannot add primitive [%s]." %
                  priminame)
            RETURN_VALUE = 10
            return
        elem.click()
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't find value [anything] for primitive type",
                                 [ANYTHING_OPT_LIST])
        elem = find_element(browser, By.NAME, 'primitive[params][binfile]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[params][binfile]]")
            RETURN_VALUE = 10
            return
        elem.clear()
        elem.send_keys("file")
        # Set start timeout value in 35s
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't find edit button for start operation",
                                 [EDIT_START_TIMEOUT, MODAL_TIMEOUT])
        fill_value(browser, 'op[timeout]', 35)
        submit_operation_params(browser, timeout_scale, 10,
                                ". Couldn't Apply changes for start operation")
        time.sleep(timeout_scale)
        # Set stop timeout value in 15s and on-fail
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't find edit button for stop operation",
                                 [EDIT_STOP_TIMEOUT, MODAL_TIMEOUT])
        fill_value(browser, 'op[timeout]', 15)
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't add on-fail option for stop operation", [MODAL_STOP])
        submit_operation_params(browser, timeout_scale, 10,
                                ". Couldn't Apply changes for stop operation")
        # Set monitor timeout value in 9s and interval in 13s
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't find edit button for monitor operation",
                                 [EDIT_MONITOR_TIMEOUT, MODAL_MONITOR_TIMEOUT])
        fill_value(browser, 'op[timeout]', 9)
        fill_value(browser, 'op[interval]', 13)
        submit_operation_params(browser, timeout_scale, 10,
                                ". Couldn't Apply changes for monitor operation")
        elem = find_element(browser, By.NAME, 'primitive[meta][target-role]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[meta][target-role]]. " +
                  "Cannot add primitive [%s]." % priminame)
            RETURN_VALUE = 10
            return
        elem.click()
        check_and_click_by_xpath(browser, timeout_scale, 10,
                                 ". Couldn't find value [Started] for primitive target-role",
                                 [TARGET_ROLE_STARTED])
        elem = find_element(browser, By.NAME, 'submit')
        if not elem:
            print("ERROR: Couldn't find submit button for primitive [%s] creation." % priminame)
            RETURN_VALUE = 10
        else:
            elem.click()
        if verify_success(browser):
            print("INFO: Successfully added primitive [%s] of class [ocf:heartbeat:anything]" %
                  priminame)
            set_test_status('add_primitive', 'passed')
        else:
            print("ERROR: Could not create primitive [%s]" % priminame)
            RETURN_VALUE = 10

def remove_rsc(browser, name, timeout_scale, version, testname):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    testname = checkstr(testname)
    check_edit_conf(browser, timeout_scale, version)
    print("TEST: Remove Resource: %s" % name)
    check_and_click_by_xpath(browser, timeout_scale, 11,
                             "Cannot edit or remove resource [%s]" % name,
                             [HREF_DELETE_FORMAT % name, COMMIT_BTN_DANGER, CONFIG_EDIT])
    if RETURN_VALUE == 11:
        print("ERROR: One of the elements required to remove resource [%s] was not found" % name)
        return
    if is_driver(browser):
        elem = find_element(browser, By.XPATH, HREF_DELETE_FORMAT % name, 5)
        if not elem:
            print("INFO: Successfully removed resource [%s]" % name)
            set_test_status(testname, 'passed')
        else:
            print("ERROR: Failed to remove resource [%s]" % name)
            RETURN_VALUE = 11

def add_clone(browser, clone, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    print("TEST: Adding clone [%s]" % clone)
    if is_driver(browser):
        test_click_on(browser, 'Resource', timeout_scale)
        check_and_click_by_xpath(browser, timeout_scale, 12, "on Create Clone [%s]" % clone,
                                 [CLONE_DATA_HELP_FILTER])
        elem = find_element(browser, By.NAME, 'clone[id]')
        if not elem:
            print("ERROR: Couldn't find element [clone[id]]. No text-field where to type clone id")
            RETURN_VALUE = 12
            return
        elem.send_keys(str(clone))
        time.sleep(timeout_scale)
        check_and_click_by_xpath(browser, timeout_scale, 12, "while adding clone [%s]" % clone,
                                 [CLONE_CHILD, OPT_STONITH, TARGET_ROLE_FORMAT % 'clone',
                                  TARGET_ROLE_STARTED, RSC_OK_SUBMIT])
        if verify_success(browser):
            print("INFO: Successfully added clone [%s] of [stonith-sbd]" % clone)
            set_test_status('add_clone', 'passed')
        else:
            print("ERROR: Could not create clone [%s]" % clone)
            RETURN_VALUE = 12

def add_group(browser, groupname, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    test_click_on(browser, 'Resource', timeout_scale)
    print("TEST: Adding group [%s]" % groupname)
    check_and_click_by_xpath(browser, timeout_scale, 15, "while adding group [%s]" % groupname,
                             [GROUP_DATA_FILTER])
    if is_driver(browser):
        elem = find_element(browser, By.NAME, 'group[id]')
        if not elem:
            print("ERROR: Couldn't find text-field [group[id]] to input group id")
            RETURN_VALUE = 15
            return
        elem.send_keys(str(groupname))
        time.sleep(timeout_scale)
        check_and_click_by_xpath(browser, timeout_scale, 15, "while adding group [%s]" % groupname,
                                 [STONITH_CHKBOX, TARGET_ROLE_FORMAT % 'group', TARGET_ROLE_STARTED,
                                  RSC_OK_SUBMIT])
        if verify_success(browser):
            print("INFO: Successfully added group [%s] of [stonith-sbd]" % groupname)
            set_test_status('add_group', 'passed')
        else:
            print("ERROR: Could not create group [%s]" % groupname)
            RETURN_VALUE = 15

def click_around_edit_conf(browser, timeout_scale):
    print("TEST: Checking around Edit Configuration")
    print("TEST: Will click on Constraints, Nodes, Tags, Alerts and Fencing")
    check_and_click_by_xpath(browser, timeout_scale, 17,
                             "while checking around edit configuration",
                             [HREF_CONSTRAINTS, HREF_NODES, HREF_TAGS, HREF_ALERTS, HREF_FENCING])
    if RETURN_VALUE != 17:
        set_test_status('click_around_edit_conf', 'passed')

# Set STONITH/sbd in maintenance. Assumes stonith-sbd resource is the last one listed on the
# resources table
def set_stonith_maintenance(browser, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    # wait for page to fully load
    time.sleep(timeout_scale)
    if is_driver(browser):
        totalrows = len(browser.find_elements_by_xpath(RSC_ROWS))
        if totalrows <= 0:
            totalrows = 1
    print("TEST: Placing stonith-sbd in maintenance")
    check_and_click_by_xpath(browser, timeout_scale, 16,
                             ". Couldn't find stonith-sbd menu to place it in maintenance mode",
                             [DROP_DOWN_FORMAT % totalrows, STONITH_MAINT_ON,
                              COMMIT_BTN_DANGER])
    if verify_success(browser):
        print("INFO: stonith-sbd successfully placed in maintenance mode")
        set_test_status('set_stonith_maintenance', 'passed')
    else:
        print("ERROR: failed to place stonith-sbd in maintenance mode")
        RETURN_VALUE = 16

def disable_stonith_maintenance(browser, timeout_scale):
    global RETURN_VALUE
    print("TEST: Re-activating stonith-sbd")
    check_and_click_by_xpath(browser, timeout_scale, 17,
                             ". Could not find Disable Maintenance Mode button for stonith-sbd",
                             [STONITH_MAINT_OFF, COMMIT_BTN_DANGER])
    if verify_success(browser):
        print("INFO: stonith-sbd successfully reactivated")
        set_test_status('disable_stonith_maintenance', 'passed')
    else:
        print("ERROR: failed to reactive stonith-sbd from maintenance mode")
        RETURN_VALUE = 17

def view_details_first_node(browser, timeout_scale):
    timeout_scale = checkint(timeout_scale)
    test_click_on(browser, 'Nodes', timeout_scale)
    print("TEST: Checking details of first cluster node")
    check_and_click_by_xpath(browser, timeout_scale, 18,
                             ". Could not find first node pull down menu", [NODE_DETAILS])
    time.sleep(5*timeout_scale)
    check_and_click_by_xpath(browser, timeout_scale, 18,
                             ". Could not find button to dismiss node details popup",
                             [DISMISS_MODAL])
    time.sleep(timeout_scale)
    if RETURN_VALUE != 18:
        set_test_status('view_details_first_node', 'passed')

def clear_state_first_node(browser, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    print("TEST: Clear state of first cluster node")
    check_and_click_by_xpath(browser, timeout_scale, 19,
                             ". Could not find pull down menu for first cluster node",
                             [CLEAR_STATE])
    test_click_on(browser, 'Clear state', timeout_scale)
    time.sleep(2*timeout_scale)
    check_and_click_by_xpath(browser, timeout_scale, 19,
                             ". Could not clear the state of the first node", [COMMIT_BTN_DANGER])
    if verify_success(browser):
        print("INFO: cleared state of first node successfully")
        set_test_status('clear_state_first_node', 'passed')
        time.sleep(2*timeout_scale)
    else:
        print("ERROR: failed to clear state of the first node")
        RETURN_VALUE = 19

def set_first_node_maintenance(browser, timeout_scale):
    global RETURN_VALUE
    print("TEST: switching node to maintenance")
    check_and_click_by_xpath(browser, timeout_scale, 20,
                             ". Could not find Switch to Maintenance toggle button for node",
                             [NODE_MAINT, COMMIT_BTN_DANGER])
    if verify_success(browser):
        print("INFO: node successfully switched to maintenance mode")
        set_test_status('set_first_node_maintenance', 'passed')
    else:
        print("ERROR: failed to switch node to maintenance mode")
        RETURN_VALUE = 20

def disable_maintenance_first_node(browser, timeout_scale):
    global RETURN_VALUE
    print("TEST: switching node to ready")
    check_and_click_by_xpath(browser, timeout_scale, 21,
                             ". Could not find Switch to Maintenance toggle button for node",
                             [NODE_READY, COMMIT_BTN_DANGER])
    if verify_success(browser):
        print("INFO: node successfully switched to ready mode")
        set_test_status('disable_maintenance_first_node', 'passed')
    else:
        print("ERROR: failed to switch node to ready mode")
        RETURN_VALUE = 21

def generate_report(browser, timeout_scale):
    global RETURN_VALUE
    timeout_scale = checkint(timeout_scale)
    print("TEST: click on Generate report")
    time.sleep(2*timeout_scale) # Wait for History page to load
    check_and_click_by_xpath(browser, timeout_scale, 22,
                             ". Could not find button for Generate report", [GENERATE_REPORT])
    # Need to wait here because there are 2 success notices being shown in the GUI: on clicking
    # the Generate # report button and on completing the generation. This next sleep() waits for
    # the first notice to disappear before waiting for the second one
    time.sleep(5*timeout_scale)
    if verify_success(browser):
        print("INFO: successfully generated report")
        set_test_status('generate_report', 'passed')
    else:
        print("ERROR: failed to generate report")
        RETURN_VALUE = 22

### SSH helper functions

def check_cluster_conf_ssh(ssh, command, mustmatch):
    command = checkstr(command)
    if is_ssh(ssh):
        resp = ssh.exec_command(command)
        out = resp[1].read().decode().rstrip('\n')
        err = resp[2].read().decode().rstrip('\n')
        print("INFO: ssh command [%s] got output [%s] and error [%s]" % (command, out, err))
        if err:
            print("ERROR: got an error over SSH: [%s]" % err)
            return False
        if isinstance(mustmatch, str):
            if mustmatch:
                if out.find(mustmatch) >= 0:
                    return True
                else:
                    return False
            else:
                return out == mustmatch
        elif isinstance(mustmatch, list):
            for exp in mustmatch:
                if out.find(str(exp)) < 0:
                    return False
            return True
        else:
            print("ERROR: check_cluster_conf_ssh argument mustmatch must be of type str or list")
            return False
    else:
        return False

### Tests over SSH

def ssh_verify_stonith(ssh):
    global RETURN_VALUE
    if check_cluster_conf_ssh(ssh, "crm status | grep stonith-sbd", "unmanaged"):
        print("INFO: stonith-sbd is unmanaged")
        set_test_status('set_stonith_maintenance', 'passed')
    else:
        print("ERROR: stonith-sbd is not unmanaged but should be")
        set_test_status('set_stonith_maintenance', 'failed')
        RETURN_VALUE = 23

def ssh_verify_node_maintenance(ssh):
    global RETURN_VALUE
    if check_cluster_conf_ssh(ssh, "crm status | grep -i ^node", "maintenance"):
        print("INFO: cluster node set successfully in maintenance mode")
        set_test_status('set_first_node_maintenance', 'passed')
    else:
        print("ERROR: cluster node failed to switch to maintenance mode")
        set_test_status('set_first_node_maintenance', 'failed')
        RETURN_VALUE = 24

def ssh_verify_primitive(ssh, myprimitive, version):
    global RETURN_VALUE
    matches = ["%s anything" % str(myprimitive), "binfile=file", "op start timeout=35s",
               "op monitor timeout=9s interval=13s", "meta target-role=Started"]
    if Version(checkstr(version)) < Version('15'):
        matches.append("op stop timeout=15s")
    else:
        matches.append("op stop timeout=15s on-fail=stop")
    if check_cluster_conf_ssh(ssh, "crm configure show", matches):
        print("INFO: primitive [%s] correctly defined in the cluster configuration" % myprimitive)
        set_test_status('add_primitive', 'passed')
    else:
        print("ERROR: primitive [%s] missing from cluster configuration" % myprimitive)
        set_test_status('add_primitive', 'failed')
        RETURN_VALUE = 25

def ssh_verify_primitive_removed(ssh):
    global RETURN_VALUE
    if check_cluster_conf_ssh(ssh, "crm resource list | grep ocf::heartbeat:anything", ''):
        print("INFO: primitive successfully removed")
        set_test_status('remove_primitive', 'passed')
    else:
        print("ERROR: primitive [%s] still present in the cluster while checking with SSH" %
              myprimitive)
        set_test_status('remove_primitive', 'failed')
        RETURN_VALUE = 26

### MAIN

# Command line argument parsing
parser = argparse.ArgumentParser(description='HAWK GUI interface Selenium test')
parser.add_argument('-b', '--browser', type=str,
                    help='Browser to use in the test. Can be: firefox, chrome, chromium')
parser.add_argument('-H', '--host', type=str, default='localhost',
                    help='Host or IP address where HAWK is running')
parser.add_argument('-P', '--port', type=str, default='7630',
                    help='TCP port where HAWK is running')
parser.add_argument('-p', '--prefix', type=str, default='',
                    help='Prefix to add to Resources created during the test')
parser.add_argument('-t', '--test-version', type=str, default='',
                    help='Test version. Ex: 12-SP3, 12-SP4, 15, 15-SP1')
parser.add_argument('-s', '--secret', type=str, default='',
                    help='root SSH Password of the HAWK node')
parser.add_argument('-r', '--results', type=str, default='',
                    help='Generate hawk_test.results file')
args = parser.parse_args()
if not args.browser:
    print('ERROR: must specify a browser with --browser')
    parser.print_help()
    quit(3)

# Set URL to use
mainlink = 'https://' + args.host.lower() + ':' + args.port

# Create appropiate driver
if args.browser.lower() in ['chrome', 'chromium']:
    browser = webdriver.Chrome()
    timeout_scale = 1
elif args.browser.lower() == 'firefox':
    profile = webdriver.FirefoxProfile()
    profile.accept_untrusted_certs = True
    profile.assume_untrusted_cert_issuer = True
    browser = webdriver.Firefox(firefox_profile=profile)
    timeout_scale = 2.5
else:
    print('ERROR: --browser must be firefox, chrome or chromium')
    quit(3)
browser.maximize_window()

# Establish SSH connection to verify status only if SSH password was supplied
if args.secret:
    ssh = paramiko.SSHClient()
    ssh.load_system_host_keys()
    ssh.set_missing_host_key_policy(paramiko.WarningPolicy)
    ssh.connect(hostname=args.host.lower(), username="root", password=args.secret)

# Initialize result set
initialize_result_set(args.test_version.lower(), args.browser.lower())

# Resources to create
if args.prefix and not re.match(r"^\w+$", args.prefix.lower()):
    print("ERROR: Prefix must contain only numbers and letters. Ignoring")
    args.prefix = ''
mycluster = args.prefix.lower() + 'Anderes'
myprimitive = args.prefix.lower() + 'cool_primitive'
myclone = args.prefix.lower() + 'cool_clone'
mygroup = args.prefix.lower() + 'cool_group'

# Variables for texts that change between chrome and firefox drivers
troubleshoot = link_by_browser(browser, 'troubleshooting')
monitoring = link_by_browser(browser, 'monitoring')

# Tests to perform
browser.get(mainlink)
hawk_log_in(browser)
time.sleep(timeout_scale)
set_stonith_maintenance(browser, timeout_scale)
if args.secret:
    ssh_verify_stonith(ssh)
disable_stonith_maintenance(browser, timeout_scale)
view_details_first_node(browser, timeout_scale)
clear_state_first_node(browser, timeout_scale)
set_first_node_maintenance(browser, timeout_scale)
if args.secret:
    ssh_verify_node_maintenance(ssh)
disable_maintenance_first_node(browser, timeout_scale)
add_new_cluster(browser, mycluster, timeout_scale)
remove_cluster(browser, mycluster, timeout_scale)
test_click_on(browser, 'Dashboard', timeout_scale)
click_if_major_version(browser, args.test_version.lower(), "15", troubleshoot, timeout_scale)
# Only click on History and on Generate Report in Firefox if testing 15+
if args.browser in ['chrome', 'chromium'] or Version(args.test_version.lower()) >= Version('15'):
    test_click_on(browser, 'History', timeout_scale, 'test_click_on_history')
    time.sleep(2*timeout_scale)
    generate_report(browser, timeout_scale)
test_click_on(browser, 'Command Log', timeout_scale, 'test_click_on_command_log')
click_if_major_version(browser, args.test_version.lower(), "15", monitoring, timeout_scale)
test_click_on(browser, 'Status', timeout_scale, 'test_click_on_status')
add_primitive(browser, myprimitive, timeout_scale, args.test_version.lower())
if args.secret:
    ssh_verify_primitive(ssh, myprimitive, args.test_version.lower())
remove_rsc(browser, myprimitive, timeout_scale, args.test_version.lower(), 'remove_primitive')
if args.secret:
    ssh_verify_primitive_removed(ssh)
add_clone(browser, myclone, timeout_scale)
remove_rsc(browser, myclone, timeout_scale, args.test_version.lower(), 'remove_clone')
add_group(browser, mygroup, timeout_scale)
remove_rsc(browser, mygroup, timeout_scale, args.test_version.lower(), 'remove_group')
click_around_edit_conf(browser, timeout_scale)

# Finish testing. Logout and close browser
test_click_on(browser, 'Logout', timeout_scale)
browser.quit()

# Save results if run with -r or --results
if args.results:
    logresults(args.results)

quit(RETURN_VALUE)
