#!/usr/bin/python3
"""Define classes and functions to handle results in HAWK GUI test"""

import time, json, hawk_test_driver, hawk_test_ssh

class resultSetError(Exception):
    """Base class for exceptions in this module."""
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class resultSet:
    def __init__(self, test_version='12-SP2'):
        self.test_version = str(test_version)
        self.my_tests = []
        for func in dir(hawk_test_driver.hawkTestDriver):
            if func.find('test_') == 0 and callable(getattr(hawk_test_driver.hawkTestDriver, func)):
                self.my_tests.append(func)
        self.results_set = {'tests': [], 'info': {}, 'summary': {}}
        for test in self.my_tests:
            auxd = {'name': test, 'test_index': 0, 'outcome': 'failed'}
            self.results_set['tests'].append(auxd)
        self.results_set['info']['timestamp'] = time.time()
        with open('/etc/os-release', 'r') as fh:
            osrel = fh.read()
        self.results_set['info']['distro'] = str(osrel[osrel.find('ID=')+3:
                                                       osrel.find('ID_LIKE=')-1])
        self.results_set['info']['results_file'] = 'hawk_test.results'
        self.results_set['summary']['duration'] = 0
        self.results_set['summary']['passed'] = 0
        self.results_set['summary']['num_tests'] = len(self.my_tests)

    def add_ssh_tests(self):
        for func in dir(hawk_test_ssh.hawkTestSSH):
            if func.find('verify_') == 0 and callable(getattr(hawk_test_ssh.hawkTestSSH, func)):
                self.my_tests.append(func)
                auxd = {'name': str(func), 'test_index': 0, 'outcome': 'failed'}
                self.results_set['tests'].append(auxd)
        self.results_set['summary']['num_tests'] = len(self.my_tests)

    def logresults(self, filename):
        with open(filename, "w") as resfh:
            resfh.write(json.dumps(self.results_set))

    def set_test_status(self, testname, status):
        status = str(status)
        testname = str(testname)
        if status not in ['passed', 'failed']:
            raise resultSetError('test status must be either [passed] or [failed]')
        if (status.lower() == 'passed' and
                self.results_set['tests'][self.my_tests.index(testname)]['outcome'] != 'passed'):
            self.results_set['summary']['passed'] += 1
        elif (status.lower() == 'failed' and
              self.results_set['tests'][self.my_tests.index(testname)]['outcome'] != 'failed'):
            self.results_set['summary']['passed'] -= 1
        self.results_set['tests'][self.my_tests.index(testname)]['outcome'] = status.lower()
        self.results_set['summary']['duration'] = time.process_time()
        self.results_set['info']['timestamp'] = time.time()

