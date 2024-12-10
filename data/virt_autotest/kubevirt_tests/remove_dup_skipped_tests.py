import os
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

def traverse_folder(root_dir):
    # Iterate through all XML files in a path
    root_list = []
    for file in os.listdir(root_dir):
        if file.endswith(".xml"):
            file_path = os.path.join(root_dir, file)
            print(f"Reading XML file: {file_path}")
            # Parsing XML files
            tree = ET.parse(file_path)
            root = tree.getroot()
            root_list.append(root)
    return root_list

def group_all_test_cases(root_list):
    # Grouping testcase
    skipped_testcases = []
    non_skipped_testcases = []

    for root in root_list:
        for testsuite in root.iter('testsuite'):
            for testcase in testsuite.iter('testcase'):
                if testcase.find('skipped') is not None:
                    skipped_testcases.append(testcase)
                else:
                    non_skipped_testcases.append(testcase)

    # Delete duplicate testcases that appear in non-skipped testcase groups
    non_skipped_names = [testcase.attrib['name'] for testcase in non_skipped_testcases]
    tmp_skipped_testcases = [testcase for testcase in skipped_testcases if testcase.attrib['name'] not in non_skipped_names]

    # Remove duplicate skipped testcases by name
    unique_skipped_testcases = []
    skipped_names = set()

    for testcase in tmp_skipped_testcases:
        name = testcase.attrib['name']
        if name not in skipped_names:
            unique_skipped_testcases.append(testcase)
            skipped_names.add(name)

    return unique_skipped_testcases, non_skipped_testcases

def remove_skipped_case_in_files(root_dir):
    # Iterate through all XML files in a path
    for file in os.listdir(root_dir):
        if file.endswith(".xml"):
            file_path = os.path.join(root_dir, file)
            print(f"Processing XML file: {file_path}")
            # Parsing XML files
            tree = ET.parse(file_path)
            root = tree.getroot()
            # Iterate over all <testcase> elements and remove those with the <skipped /> tag
            for testsuite in root.iter('testsuite'):
                for testcase in list(testsuite.iter('testcase')):
                    if testcase.find('skipped') is not None:
                        testsuite.remove(testcase)
            # Overwrite the original file
            tree.write(file_path, encoding='utf-8', xml_declaration=True)

def create_new_skipped_file(filename, unique_skipped_testcases):
    # Create a new XML
    new_root = ET.Element("testsuite", attrib={"errors": "0",
                                               "failures": "0",
                                               "name": "SKIPPED_TEST",
                                               "tests": str(len(unique_skipped_testcases)),
                                               "skipped": str(len(unique_skipped_testcases)),
                                               "time": "0"})

    for testcase in unique_skipped_testcases:
        testcase.set('classname', 'SKIPPED_TEST')
        new_root.append(testcase)

    # Generate XML file
    new_tree = ET.ElementTree(new_root)
    new_tree.write(filename, encoding="UTF-8", xml_declaration=True)


if __name__ == '__main__':
    RESULT_DIR = sys.argv[1]
    SKIPPED_FILENAME = os.path.join(RESULT_DIR, 'skipped_test.xml')
    root_list = traverse_folder(RESULT_DIR)
    unique_skipped_testcases, _ = group_all_test_cases(root_list)
    remove_skipped_case_in_files(RESULT_DIR)
    create_new_skipped_file(SKIPPED_FILENAME, unique_skipped_testcases)

