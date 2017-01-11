#!/bin/bash

# Variables Definition
# --------------------
PWD=$(/usr/bin/pwd)
DIR="/var/tmp"
LIST_INSTALLED_IBM_VERSIONS="$DIR/javas_ibm"
LIST_INSTALLED_JDK_VERSIONS="$DIR/javas_jdk"
LIST_INSTALLED_GCJ_VERSIONS="$DIR/javas.gcj"
RPM_QUERY_JAVA="$DIR/zypper_se_java"
LIST_ALL_INSTALLED_VERSIONS="$DIR/javas_installed"
HELLO_WORLD="$DIR/Hello.java"
HELLO="$DIR/Hello"
LIST_ALL_JAVA_ALTERNATIVES="$DIR/java_alternatives"
LIST_ALL_JAVAC_ALTERNATIVES="$DIR/javac_alternatives"
LIST_ALL_JAVAPLUGIN_ALTERNATIVES="$DIR/javaplugin_alternatives"

# Function Definitions
# --------------------
# Test if there's any version of Java installed in the system
is_java_installed() {
    if [[ -s $LIST_ALL_INSTALLED_VERSIONS ]] ; then
        return 0
    else
        return 1
    fi
}

# Writes a very basic hello world program in Java language
create_hello_java() {
    # Construct the source code
        cat << EOF > $HELLO_WORLD
public class Hello
{
    public static void main (String argv[])
    {
        System.out.println("Hello World!");
    }
}
EOF
}

# Remove unecessarry files
clean_up() {
    rm $LIST_INSTALLED_IBM_VERSIONS
    rm $LIST_INSTALLED_JDK_VERSIONS
    rm $RPM_QUERY_JAVA
    rm $LIST_ALL_INSTALLED_VERSIONS
    rm $HELLO_WORLD
}

# Find each (already) installed java version
find_all_installed_java() {
    # Construct temp files which are needed in order to
    # determine how many java versions are installed along with their versions
    rpm -qa | grep ^java- > $RPM_QUERY_JAVA

    # File that contains all the IBM Java installed in the system
    grep "^java-" $RPM_QUERY_JAVA | grep "\-ibm" | awk -F 'ibm' '{print $1 "ibm"}' | sort -r | uniq > $LIST_INSTALLED_IBM_VERSIONS

    # File that contains all the OpenJDK Java installed in the system
    grep "^java-" $RPM_QUERY_JAVA | grep "openjdk" | awk -F 'openjdk' '{print $1 "openjdk"}' | sort -r | uniq > $LIST_INSTALLED_JDK_VERSIONS

    # File that contains all the GCC Java installed in the system
    grep "^java-" $RPM_QUERY_JAVA | grep "gcj" | awk -F 'gcj' '{print $1 "gcj-compat"}' | sort -r | uniq > $LIST_INSTALLED_GCJ_VERSIONS

    # Add JDK and IBM versions altogether, into one single file
    cat $LIST_INSTALLED_JDK_VERSIONS $LIST_INSTALLED_IBM_VERSIONS $LIST_INSTALLED_GCJ_VERSIONS > $LIST_ALL_INSTALLED_VERSIONS
}

# Save the ouput of "update-alternatives --list java"
list_all_java_alternatives () {
    update-alternatives --list java > $LIST_ALL_JAVA_ALTERNATIVES
}

# Save the output of "update-alternatives --list javac"
list_all_javac_alternatives () {
    update-alternatives --list javac > $LIST_ALL_JAVAC_ALTERNATIVES
}

# Save the output of "update-alternatives --list javaplugin"
list_all_javaplugin_alternatives () {
    update-alternatives --list javaplugin > $LIST_ALL_JAVAPLUGIN_ALTERNATIVES
}

# Check if there's a 1:1 analogy with update-alternatives and the java versions
test_java_alternatives () {
    list_all_java_alternatives
    java_versions=$(cat $LIST_ALL_INSTALLED_VERSIONS | wc -l)
    java_alternatives=$(cat $LIST_ALL_JAVA_ALTERNATIVES | wc -l)
    if [ $java_versions -eq $java_alternatives ]; then
        echo "java: PASS"
    else
        echo "java: FAIL"
        echo "Debug:"
        echo "Number of java versions: $java_versions and and number of java_alternatives: $java_alternatives"
        echo
        echo "List all java alternatives"
        cat $LIST_ALL_JAVA_ALTERNATIVES
        for i in $(update-alternatives --list java); do rpm -qf $i; done
        exit 1
    fi
}

# Check if there is 1:1 analogy with:
# javac alternatives and java*devel pkgs installed
# java alternatives and the java pkgs installed
test_javac_alternatives () {
    list_all_javac_alternatives
#    java_versions=$(cat $LIST_ALL_INSTALLED_VERSIONS | wc -l)
    javac_versions=$(rpm -qa | grep java | grep devel | wc -l)
    javac_alternatives=$(cat $LIST_ALL_JAVAC_ALTERNATIVES | wc -l)
    if [ $javac_versions -eq $javac_alternatives ]; then
	echo "javac: PASS"
    else
	echo "javac: FAIL"
        echo "Debug:"
        echo "Number of java versions: $java_versions and number of javac_alternatives $javac_alternatives"
        echo
        echo "List all javac alternatives"
        cat $LIST_ALL_JAVAC_ALTERNATIVES
	exit 1
    fi
}

# Check if there's 1:1 analogy with javaplugin and java-ibm versions
test_javaplugin_alternatives () {
    list_all_javaplugin_alternatives
    # This exists only for java-ibm so far
    java_plugins=$(rpm -qa | grep java | grep plugin | wc -l)
    javaplugin_alternatives=$(cat $LIST_ALL_JAVAPLUGIN_ALTERNATIVES | wc -l)
    if [ $java_plugins -eq $javaplugin_alternatives ]; then
	echo "javaplugin: PASS"
    else
	echo "javaplugin: FAIL"
	exit 1
    fi
}

test_java_version_active () {
    # find active java version
    java_version_active=`java -version 2>&1 | awk '/version/{print $NF}' | sed 's/"//g' | awk -F "_" '{print $1}'`
}

test_javac_version_active () {
    # find active javac version
    javac_version_active=`javac -version 2>&1 | awk '/javac/{print $2}' | awk -F "-" '{print $1}' | awk -F "_" '{print $1}'`
}

check_version_active_vs_dot () {
    if [ $# -ne 2 ]; then
	echo "Please pass version and executable name";
	return;
    fi
    version=$1
    name=$2

    dot_version_short=`echo $dot_version | awk -F '-' '{print $1}'`   
    if [ $version == $dot_version_short ]; then
	echo "check linked $name version: PASS"
    else
        if [[ "$dot_version_short" == "1.7.1" ]]; then
            # Special Case
            if [[ "$version" == "1.7.0" ]]; then
                echo -n "check linked $name version: OK"
                        "INFO: linked $name is: $version which is normal according to bnc#1014602"
            fi
        else
	    echo -n "check linked $name version: FAIL"
                    "linked $name is: $version should be $dot_version_short"
	    exit 1
        fi
    fi
}

# ==== #
# MAIN # Testing starts here ...
# ==== #

clear
echo "----------------------------"
echo "Find installed Java versions"
echo "----------------------------"
find_all_installed_java;
if is_java_installed; then
    cat $LIST_ALL_INSTALLED_VERSIONS
else
    echo "No Java versions found on the system"
    exit 1
fi
echo -e "\n------------------------------------------------------"
echo "Test if there's an alternative per Java, Devel, Plugin"
echo "------------------------------------------------------"
test_java_alternatives
test_javac_alternatives
test_javaplugin_alternatives

# Create hello world java source code
create_hello_java

echo -e "\n---------------------------------------------------------------------------------------"
echo "Set java/javac/plugin update alternative for each Java version, compile/run Hello World"
echo "---------------------------------------------------------------------------------------"

# Start testing all java versions
for java_version in $(cat $LIST_ALL_INSTALLED_VERSIONS); do
    echo $java_version:
    if [[ $java_version == *"gcj-compat"* ]]; then
        echo "SKIPPING. We do not test BSK Repo"
        continue
    fi
    # Current java under test
    dot_version=$(echo $java_version | awk -F '-' '{print $2 "-" $3}' | sed 's/_/./g')
    # Test if there's an alternativ for java, and if yes, set it as the current used one
    if grep $dot_version $LIST_ALL_JAVA_ALTERNATIVES > /dev/null; then
        java=$(grep $dot_version $LIST_ALL_JAVA_ALTERNATIVES)
        update-alternatives --set java $java
    else
        echo "Error: java alternative not found for $java_version"
        exit 1
    fi
    # Test if there's an alternative for javac, and if yes, set it as the current used one
    if grep $dot_version $LIST_ALL_JAVAC_ALTERNATIVES > /dev/null; then
        javac=$(grep $dot_version $LIST_ALL_JAVAC_ALTERNATIVES)
        update-alternatives --set javac $javac
    else
        if echo $java_version | grep ibm > /dev/null; then
            if ! rpm -qa | grep java | grep devel | grep $dot_version > /dev/null; then
                echo "Warning: java compiler alternative not found for $java_version"
                echo "Reason : devel pkg is not installed, thus it is normal there is not javac"
                if zypper products -i | grep sle-sdk > /dev/null; then
                    echo "Status : Error! The devel pkg should be installed. Check your repos!"
                    exit 1
                else
                    echo "Status : Accepted because there is no SDK installed in the SUT"
                fi
                echo "SKIP Testing $java_version"
                echo
                continue
            fi
        fi
        echo "Error: java compiler alternative not found for $java_version"
        exit 1
    fi
    # Test if there's an alternativ for javaplugin, and if yes, set it as the current used one
    # So far, only java-ibm offers this
    if echo $java_version | grep ibm > /dev/null; then
	    if grep $dot_version $LIST_ALL_JAVAPLUGIN_ALTERNATIVES > /dev/null; then
		javaplugin=$(grep $dot_version $LIST_ALL_JAVAPLUGIN_ALTERNATIVES)
		update-alternatives --set javaplugin $javaplugin
	    else
		echo "Error: java plugin alternative not found for $java_version"
		exit 1
	    fi
    fi

    # Test version active (linked)
    test_java_version_active
    test_javac_version_active
    check_version_active_vs_dot "$java_version_active" "java"
    check_version_active_vs_dot "$javac_version_active" "javac"

    # Compile Hello World
    javac $HELLO_WORLD
    rq=$?
    if [ $rq -ne 0 ]; then
        echo "Java Compiler failed"
        exit 1
    else
        echo "Java Compiler: PASS"
    fi

    # JVM is unable to load the *.class file unless you are into
    # the very same directory that the file exist 
    cd $DIR; java Hello > /dev/null
    rq=$?
    if [ $rq -ne 0 ]; then
        echo "Java failed to run the program"
        exit 1
    else
        echo "Java runtime: PASS"
    fi

    # Go back to previous directory
    cd $PWD

    # Delete the successfully compiled files: class and binary of Hello World
    rm $HELLO.class
    echo
done

# Breakdown
clean_up;
