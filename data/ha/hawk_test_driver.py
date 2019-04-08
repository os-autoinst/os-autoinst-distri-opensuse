#!/usr/bin/python3
"""Define Selenium driver related functions and classes to test the HAWK GUI"""

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.common.exceptions import ElementNotInteractableException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from distutils.version import LooseVersion as Version
import time, hawk_test_results

### Error messages
STONITH_ERR = ". Couldn't find stonith-sbd menu to place it in maintenance mode"
STONITH_ERR_OFF = ". Could not find Disable Maintenance Mode button for stonith-sbd"
MAINT_TOGGLE_ERR = ". Could not find Switch to Maintenance toggle button for node"
PRIMITIVE_TARGET_ROLE_ERR = ". Couldn't find value [Started] for primitive target-role"
XPATH_ERR_FMT = "check_and_click_by_xpath requires a list of xpath strings. Got [%s]"

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

class hawkTestDriverError(Exception):
    """Base class for exceptions in this module."""
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class hawkTestDriver:
    def __init__(self, addr='localhost', port='7630', browser='firefox', version='12-SP2'):
        self.set_addr(addr)
        self.set_port(port)
        self.timeout_scale = 1
        self.set_browser(browser)
        self.driver = ''
        self.retval = 0
        self.test_version = str(version)

    def set_addr(self, addr):
        if isinstance(addr, str):
            self.addr = addr
        else:
            raise hawkTestDriverError('Unexpected type for host address')

    def set_port(self, port):
        port = str(port)
        if port.isdigit() and 1 <= int(port) <= 65536:
            self.port = port
        else:
            raise hawkTestDriverError('Port must be an integer')

    def set_browser(self, browser):
        browser = browser.lower()
        if browser in ['chrome', 'chromium', 'firefox']:
            self.browser = browser
            if browser == 'firefox':
                self.timeout_scale = 2.5
            else:
                self.timeout_scale = 1
        else:
            raise hawkTestDriverError('Browser must be chrome, chromium or firefox')

    def set_retval(self, value):
        self.retval = int(value)

    def get_retval(self):
        return self.retval

    def _connect(self):
        if self.browser in ['chrome', 'chromium']:
            self.driver = webdriver.Chrome()
        elif self.browser == 'firefox':
            profile = webdriver.FirefoxProfile()
            profile.accept_untrusted_certs = True
            profile.assume_untrusted_cert_issuer = True
            self.driver = webdriver.Firefox(firefox_profile=profile)
        else:
            raise hawkTestDriverError('Browser must be chrome, chromium or firefox')
        self.driver.maximize_window()
        return self.driver

    def _close(self):
        self.click_on('Logout')
        self.driver.quit()
        self.driver = ''

    def set_test_status(self, results, testname, status):
        if isinstance(results, hawk_test_results.resultSet):
            results.set_test_status(testname, status)
        else:
            raise hawkTestDriverError('results must be of type hawk_test_results.resultSet')

    # Some links by text are capitalized differently between the chrome and firefox drivers.
    def link_by_browser(self, linktext):
        if self.browser in ['chrome', 'chromium']:
            return str(linktext).upper()
        return str(linktext).capitalize()

    def _do_login(self):
        if self.driver:
            mainlink = 'https://' + self.addr.lower() + ':' + self.port
            self.driver.get(mainlink)
            elem = self.find_element(By.NAME, "session[username]")
            if not elem:
                print("ERROR: couldn't find element [session[username]]. Cannot login")
                self.driver.quit()
                self.driver = ''
                return False
            elem.clear()
            elem.send_keys("hacluster")
            elem = self.find_element(By.NAME, "session[password]")
            if not elem:
                print("ERROR: Couldn't find element [session[password]]. Cannot login")
                self.driver.quit()
                self.driver = ''
                return False
            elem.send_keys("linux")
            elem.send_keys(Keys.RETURN)
            return True
        return False

    # Clicks on element identified by clicker if major version from the test is greater or
    # equal than the version to check
    def click_if_major_version(self, version_to_check, clicker):
        if Version(self.test_version) >= Version(str(version_to_check)):
            self.click_on(clicker)

    # Support function click_on partial link test.
    def click_on(self, text):
        print("INFO: Main page. Click on %s" % text)
        elem = self.find_element(By.PARTIAL_LINK_TEXT, str(text))
        if not elem:
            print("ERROR: Couldn't find element '%s'" % text)
            self.retval = 6
            return False
        elem.click()
        time.sleep(self.timeout_scale)
        return True

    def find_element(self, bywhat, texto, tout=60):
        tout = int(tout)
        if self.driver:
            try:
                elem = WebDriverWait(self.driver,
                                     tout).until(EC.presence_of_element_located((bywhat,
                                                                                 str(texto))))
            except TimeoutException:
                print("INFO: %d seconds timeout while looking for element [%s] by [%s]" %
                      (tout, texto, bywhat))
                return False
            return elem
        return False

    def verify_success(self):
        elem = self.find_element(By.CLASS_NAME, 'alert-success', 60)
        if not elem:
            elem = self.find_element(By.PARTIAL_LINK_TEXT, 'Rename', 5)
            if not elem:
                return False
        return True

    def fill_value(self, field, tout):
        elem = self.find_element(By.NAME, str(field))
        if not elem:
            print("ERROR: couldn't find element [%s]." % str(field))
            self.retval = 10
            return
        elem.clear()
        elem.send_keys(str(tout) + "s")

    def submit_operation_params(self, retval, errmsg):
        self.check_and_click_by_xpath(int(retval), str(errmsg), [CLICK_OK_SUBMIT])

    def check_edit_conf(self):
        print("INFO: Check edit configuration")
        self.click_if_major_version("15", self.link_by_browser('configuration'))
        self.click_on('Edit Configuration')
        self.check_and_click_by_xpath(13, "Couldn't find Edit Configuration element", [CONFIG_EDIT])

    def check_and_click_by_xpath(self, retcode, errmsg, xpath_exps):
        retcode = int(retcode)
        if not isinstance(xpath_exps, list):
            self.retval = retcode
            raise hawkTestDriverError(XPATH_ERR_FMT % type(xpath_exps))
        for e in xpath_exps:
            elem = self.find_element(By.XPATH, str(e))
            if not elem:
                print("ERROR: Couldn't find element by xpath [%s] %s" % (e, errmsg))
                self.retval = retcode
                return
            try:
                elem.click()
            except ElementNotInteractableException:
                # Element is obscured. Wait and click again
                time.sleep(2*self.timeout_scale)
                elem.click()
            time.sleep(2*self.timeout_scale)

    # Generic function to perform the tests
    def test(self, testname, results, *extra):
        self._connect()
        if self._do_login():
            if getattr(self, testname)(*extra):
                self.set_test_status(results, testname, 'passed')
            else:
                self.set_test_status(results, testname, 'failed')
        self._close()

    # Set STONITH/sbd in maintenance. Assumes stonith-sbd resource is the last one listed on the
    # resources table
    def test_set_stonith_maintenance(self):
        myerr = 16
        # wait for page to fully load
        if self.find_element(By.XPATH, RSC_ROWS):
            totalrows = 1
            if self.driver:
                totalrows = len(self.driver.find_elements_by_xpath(RSC_ROWS))
                if totalrows <= 0:
                    totalrows = 1
            print("TEST: test_set_stonith_maintenance: Placing stonith-sbd in maintenance")
            self.check_and_click_by_xpath(myerr, STONITH_ERR, [DROP_DOWN_FORMAT % totalrows,
                                                               STONITH_MAINT_ON, COMMIT_BTN_DANGER])
        if self.verify_success():
            print("INFO: stonith-sbd successfully placed in maintenance mode")
            return True
        print("ERROR: failed to place stonith-sbd in maintenance mode")
        self.retval = myerr
        return False

    def test_disable_stonith_maintenance(self):
        myerr = 17
        print("TEST: test_disable_stonith_maintenance: Re-activating stonith-sbd")
        self.check_and_click_by_xpath(myerr, STONITH_ERR_OFF,
                                      [STONITH_MAINT_OFF, COMMIT_BTN_DANGER])
        if self.verify_success():
            print("INFO: stonith-sbd successfully reactivated")
            return True
        print("ERROR: failed to reactive stonith-sbd from maintenance mode")
        self.retval = myerr
        return False

    def test_view_details_first_node(self):
        myerr = 18
        print("TEST: test_view_details_first_node: Checking details of first cluster node")
        self.click_on('Nodes')
        self.check_and_click_by_xpath(myerr, ". Could not find first node pull down menu",
                                      [NODE_DETAILS])
        self.check_and_click_by_xpath(myerr,
                                      ". Could not find button to dismiss node details popup",
                                      [DISMISS_MODAL])
        time.sleep(self.timeout_scale)
        if self.retval != 18:
            return True
        return False

    def test_clear_state_first_node(self):
        myerr = 19
        print("TEST: test_clear_state_first_node")
        self.click_on('Nodes')
        self.check_and_click_by_xpath(myerr,
                                      ". Could not find pull down menu for first cluster node",
                                      [CLEAR_STATE])
        self.click_on('Clear state')
        self.check_and_click_by_xpath(myerr, ". Could not clear the state of the first node",
                                      [COMMIT_BTN_DANGER])
        if self.verify_success():
            print("INFO: cleared state of first node successfully")
            time.sleep(2*self.timeout_scale)
            return True
        print("ERROR: failed to clear state of the first node")
        self.retval = myerr
        return False

    def test_set_first_node_maintenance(self):
        myerr = 20
        print("TEST: test_set_first_node_maintenance: switching node to maintenance")
        self.click_on('Nodes')
        self.check_and_click_by_xpath(myerr, MAINT_TOGGLE_ERR, [NODE_MAINT, COMMIT_BTN_DANGER])
        if self.verify_success():
            print("INFO: node successfully switched to maintenance mode")
            return True
        print("ERROR: failed to switch node to maintenance mode")
        self.retval = myerr
        return False

    def test_disable_maintenance_first_node(self):
        myerr = 21
        print("TEST: test_disable_maintenance_first_node: switching node to ready")
        self.click_on('Nodes')
        self.check_and_click_by_xpath(myerr, MAINT_TOGGLE_ERR, [NODE_READY, COMMIT_BTN_DANGER])
        if self.verify_success():
            print("INFO: node successfully switched to ready mode")
            return True
        print("ERROR: failed to switch node to ready mode")
        self.retval = myerr
        return False

    def test_add_new_cluster(self, cluster_name):
        myerr = 7
        print("TEST: test_add_new_cluster")
        self.click_on('Dashboard')
        elem = self.find_element(By.CLASS_NAME, "btn-default")
        if not elem:
            print("ERROR: Couldn't find class 'btn-default'")
            self.retval = myerr
            return False
        elem.click()
        elem = self.find_element(By.NAME, "cluster[name]")
        if not elem:
            print("ERROR: Couldn't find element [cluster[name]]. Cannot add cluster")
            self.retval = myerr
            return False
        elem.send_keys(str(cluster_name))
        elem = self.find_element(By.NAME, "cluster[host]")
        if not elem:
            print("ERROR: Couldn't find element [cluster[host]]. Cannot add cluster")
            self.retval = myerr
            return False
        elem.send_keys(self.addr.lower())
        elem = self.find_element(By.NAME, "submit")
        if not elem:
            print("ERROR: Couldn't find submit button")
            self.retval = myerr
            return False
        elem.click()
        while True:
            elem = self.find_element(By.PARTIAL_LINK_TEXT, 'Dashboard')
            try:
                elem.click()
                return True
            except WebDriverException:
                time.sleep(1+self.timeout_scale)
        return False

    def test_remove_cluster(self, cluster_name):
        myerr = 8
        print("TEST: test_remove_cluster")
        self.click_on('Dashboard')
        elem = self.find_element(By.PARTIAL_LINK_TEXT, str(cluster_name))
        if not elem:
            print("ERROR: Couldn't find cluster [%s]. Cannot remove" % cluster_name)
            self.retval = myerr
            return False
        elem.click()
        time.sleep(2*self.timeout_scale)
        elem = self.find_element(By.CLASS_NAME, 'close')
        if not elem:
            print("ERROR: Cannot find cluster remove button")
            self.retval = myerr
            return False
        elem.click()
        time.sleep(2*self.timeout_scale)
        elem = self.find_element(By.CLASS_NAME, 'cancel')
        if not elem:
            print("ERROR: No cancel button while removing cluster [%s]" % cluster_name)
            self.retval = 9
        else:
            elem.click()
        time.sleep(self.timeout_scale)
        elem = self.find_element(By.CLASS_NAME, 'close')
        elem.click()
        time.sleep(2*self.timeout_scale)
        elem = self.find_element(By.CLASS_NAME, 'btn-danger')
        if not elem:
            print("ERROR: No OK button found while removing cluster [%s]" % cluster_name)
            self.retval = myerr
        else:
            elem.click()
        if self.verify_success():
            print("INFO: Successfully removed cluster: [%s]" % cluster_name)
            return True
        print("ERROR: Could not remove cluster [%s]" % cluster_name)
        self.retval = myerr
        return False

    def test_click_on_history(self):
        print("TEST: test_click_on_history")
        self.click_if_major_version("15", self.link_by_browser('troubleshooting'))
        if self.retval == 15:
            return False
        return self.click_on('History')

    def test_generate_report(self):
        myerr = 22
        print("TEST: test_generate_report: click on Generate report")
        self.click_if_major_version("15", self.link_by_browser('troubleshooting'))
        self.click_on('History')
        if self.find_element(By.XPATH, GENERATE_REPORT):
            self.check_and_click_by_xpath(myerr, ". Could not find button for Generate report",
                                          [GENERATE_REPORT])
            # Need to wait here because there are 2 success notices being shown in the GUI: on
            # clicking the Generate report button and on completing the generation. This next
            # sleep() waits for the first notice to disappear before waiting for the second one
            time.sleep(6)
        if self.verify_success():
            print("INFO: successfully generated report")
            return True
        print("ERROR: failed to generate report")
        self.retval = myerr
        return False

    def test_click_on_command_log(self):
        print("TEST: test_click_on_command_log")
        self.click_if_major_version("15", self.link_by_browser('troubleshooting'))
        if self.retval == 15:
            return False
        return self.click_on('Command Log')

    def test_click_on_status(self):
        print("TEST: test_click_on_status")
        return self.click_on('Status')

    def test_add_primitive(self, priminame):
        myerr = 10
        priminame = str(priminame)
        print("TEST: test_add_primitive: Add Resources: Primitive %s" % priminame)
        self.click_if_major_version("15", self.link_by_browser('configuration'))
        self.click_on('Resource')
        self.click_on('rimitive')
        # Fill the primitive
        elem = self.find_element(By.NAME, 'primitive[id]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[id]]. Cannot add primitive [%s]." %
                  priminame)
            self.retval = myerr
            return False
        elem.send_keys(str(priminame))
        elem = self.find_element(By.NAME, 'primitive[clazz]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[clazz]]. Cannot add primitive [%s]" %
                  priminame)
            self.retval = myerr
            return False
        elem.click()
        self.check_and_click_by_xpath(myerr, ". Couldn't find value [ocf] for primitive class",
                                      [OCF_OPT_LIST])
        elem = self.find_element(By.NAME, 'primitive[type]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[type]]. Cannot add primitive [%s]." %
                  priminame)
            self.retval = myerr
            return False
        elem.click()
        self.check_and_click_by_xpath(myerr, ". Couldn't find value [anything] for primitive type",
                                      [ANYTHING_OPT_LIST])
        elem = self.find_element(By.NAME, 'primitive[params][binfile]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[params][binfile]]")
            self.retval = myerr
            return False
        elem.clear()
        elem.send_keys("file")
        # Set start timeout value in 35s
        self.check_and_click_by_xpath(myerr, ". Couldn't find edit button for start operation",
                                      [EDIT_START_TIMEOUT, MODAL_TIMEOUT])
        self.fill_value('op[timeout]', 35)
        self.submit_operation_params(myerr, ". Couldn't Apply changes for start operation")
        # Set stop timeout value in 15s and on-fail
        self.check_and_click_by_xpath(myerr, ". Couldn't find edit button for stop operation",
                                      [EDIT_STOP_TIMEOUT, MODAL_TIMEOUT])
        self.fill_value('op[timeout]', 15)
        self.check_and_click_by_xpath(myerr, ". Couldn't add on-fail option for stop operation",
                                      [MODAL_STOP])
        self.submit_operation_params(myerr, ". Couldn't Apply changes for stop operation")
        # Set monitor timeout value in 9s and interval in 13s
        self.check_and_click_by_xpath(myerr, ". Couldn't find edit button for monitor operation",
                                      [EDIT_MONITOR_TIMEOUT, MODAL_MONITOR_TIMEOUT])
        self.fill_value('op[timeout]', 9)
        self.fill_value('op[interval]', 13)
        self.submit_operation_params(myerr, ". Couldn't Apply changes for monitor operation")
        elem = self.find_element(By.NAME, 'primitive[meta][target-role]')
        if not elem:
            print("ERROR: Couldn't find element [primitive[meta][target-role]]. " +
                  "Cannot add primitive [%s]." % priminame)
            self.retval = myerr
            return False
        elem.click()
        self.check_and_click_by_xpath(myerr, PRIMITIVE_TARGET_ROLE_ERR, [TARGET_ROLE_STARTED])
        elem = self.find_element(By.NAME, 'submit')
        if not elem:
            print("ERROR: Couldn't find submit button for primitive [%s] creation." % priminame)
            self.retval = myerr
        else:
            elem.click()
        if self.verify_success():
            print("INFO: Successfully added primitive [%s] of class [ocf:heartbeat:anything]" %
                  priminame)
            return True
        print("ERROR: Could not create primitive [%s]" % priminame)
        self.retval = myerr
        return False

    def remove_rsc(self, name):
        myerr = 11
        name = str(name)
        print("INFO: Remove Resource: %s" % name)
        self.check_edit_conf()
        self.check_and_click_by_xpath(myerr, "Cannot edit or remove resource [%s]" % name,
                                      [HREF_DELETE_FORMAT % name, COMMIT_BTN_DANGER, CONFIG_EDIT])
        if self.retval == myerr:
            print("ERROR: One of the elements required to remove resource [%s] wasn't found" % name)
            return False
        elem = self.find_element(By.XPATH, HREF_DELETE_FORMAT % name, 5)
        if not elem:
            print("INFO: Successfully removed resource [%s]" % name)
            return True
        print("ERROR: Failed to remove resource [%s]" % name)
        self.retval = myerr
        return False

    def test_remove_primitive(self, name):
        print("TEST: test_remove_primitive: Remove Primitive: %s" % name)
        return self.remove_rsc(name)

    def test_remove_clone(self, clone):
        print("TEST: test_remove_clone: Remove Clone: %s" % clone)
        return self.remove_rsc(clone)

    def test_remove_group(self, group):
        print("TEST: test_remove_group: Remove Group: %s" % group)
        return self.remove_rsc(group)

    def test_add_clone(self, clone):
        myerr = 12
        print("TEST: test_add_clone: Adding clone [%s]" % clone)
        self.click_if_major_version("15", self.link_by_browser('configuration'))
        self.click_on('Resource')
        self.check_and_click_by_xpath(myerr, "on Create Clone [%s]" % clone,
                                      [CLONE_DATA_HELP_FILTER])
        elem = self.find_element(By.NAME, 'clone[id]')
        if not elem:
            print("ERROR: Couldn't find element [clone[id]]. No text-field where to type clone id")
            self.retval = myerr
            return False
        elem.send_keys(str(clone))
        self.check_and_click_by_xpath(myerr, "while adding clone [%s]" % clone,
                                      [CLONE_CHILD, OPT_STONITH, TARGET_ROLE_FORMAT % 'clone',
                                       TARGET_ROLE_STARTED, RSC_OK_SUBMIT])
        if self.verify_success():
            print("INFO: Successfully added clone [%s] of [stonith-sbd]" % clone)
            return True
        print("ERROR: Could not create clone [%s]" % clone)
        self.retval = myerr
        return False

    def test_add_group(self, group):
        myerr = 15
        print("TEST: test_add_group: Adding group [%s]" % group)
        self.click_if_major_version("15", self.link_by_browser('configuration'))
        self.click_on('Resource')
        self.check_and_click_by_xpath(myerr, "while adding group [%s]" % group, [GROUP_DATA_FILTER])
        elem = self.find_element(By.NAME, 'group[id]')
        if not elem:
            print("ERROR: Couldn't find text-field [group[id]] to input group id")
            self.retval = myerr
            return False
        elem.send_keys(str(group))
        self.check_and_click_by_xpath(myerr, "while adding group [%s]" % group,
                                      [STONITH_CHKBOX, TARGET_ROLE_FORMAT % 'group',
                                       TARGET_ROLE_STARTED, RSC_OK_SUBMIT])
        if self.verify_success():
            print("INFO: Successfully added group [%s] of [stonith-sbd]" % group)
            return True
        print("ERROR: Could not create group [%s]" % group)
        self.retval = 15
        return False

    def test_click_around_edit_conf(self):
        myerr = 14
        print("TEST: test_click_around_edit_conf")
        print("TEST: Will click on Constraints, Nodes, Tags, Alerts and Fencing")
        self.check_edit_conf()
        self.check_and_click_by_xpath(myerr, "while checking around edit configuration",
                                      [HREF_CONSTRAINTS, HREF_NODES, HREF_TAGS,
                                       HREF_ALERTS, HREF_FENCING])
        if self.retval != myerr:
            return True
        return False
