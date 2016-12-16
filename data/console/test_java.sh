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
        exit 2
    fi
}

# Check if there is 1:1 analogy with javac alternatives and java versions
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
	exit 2
    fi
}

# Check if there's 1:1 analogy with javaplugin and java-ibm versions
test_javaplugin_alternatives () {
    list_all_javaplugin_alternatives
    # This exists only for java-ibm so far
    java_versions=$(cat $LIST_ALL_INSTALLED_VERSIONS | grep ibm | wc -l)
    javaplugin_alternatives=$(cat $LIST_ALL_JAVAPLUGIN_ALTERNATIVES | wc -l)
    if [ $java_versions -eq $javaplugin_alternatives ]; then
	echo "javaplugin: PASS"
    else
	echo "javaplugin: FAIL"
	exit 2
    fi
}

test_java_version_active () {
    # find active java version
    java_version_active=`java -version 2>&1 | awk '/version/{print $NF}' | sed 's/"//g' | awk -F "_" '{print $1}'`
    #echo $java_version_active
}

test_javac_version_active () {
    # find active javac version
    javac_version_active=`javac -version 2>&1 | awk '/javac/{print $2}' | awk -F "-" '{print $1}' | awk -F "_" '{print $1}'`
    #echo $javac_version_active
}

check_java_version_active_vs_dot () {
    dot_version_short=`echo $dot_version | awk -F '-' '{print $1}'`   
        #echo $dot_version_short $java_version_active
    if [ $java_version_active ==  $dot_version_short ]; then
	echo "check linked java version: PASS"
        #echo $dot_version_short
    else
	echo "check linked java version: FAIL"
        echo "linked java is: $java_version_active should be $dot_version_short"
	exit 2
    fi
}

check_javac_version_active_vs_dot () {
    dot_version_short=`echo $dot_version | awk -F '-' '{print $1}'`   
    if [ $javac_version_active ==  $dot_version_short ]; then
	echo "check linked javac version: PASS"
        #echo $dot_version_short
    else
	echo "check linked javac version: FAIL"
        echo "linked java is: $java_version_active should be $dot_version_short" 
        echo "*****************************************************************"
	exit 2
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
echo -e "\n-----------------------------------------------"
echo "Test if there's an alternative per Java version"
echo "-----------------------------------------------"
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
        exit 3
    fi
    # Test if there's an alternativ for javac, and if yes, set it as the current used one
    if grep $dot_version $LIST_ALL_JAVAC_ALTERNATIVES > /dev/null; then
        javac=$(grep $dot_version $LIST_ALL_JAVAC_ALTERNATIVES)
        update-alternatives --set javac $javac
    else
        echo "Error: java compiler alternative not found for $java_version"
        exit 4
    fi
    # Test if there's an alternativ for javaplugin, and if yes, set it as the current used one
    # So far, only java-ibm offers this
    if echo $java_version | grep ibm > /dev/null; then
	    if grep $dot_version $LIST_ALL_JAVAPLUGIN_ALTERNATIVES > /dev/null; then
		javaplugin=$(grep $dot_version $LIST_ALL_JAVAPLUGIN_ALTERNATIVES)
		update-alternatives --set javaplugin $javaplugin
	    else
		echo "Error: java plugin alternative not found for $java_version"
		exit 5
	    fi
    fi

    # Test version active (linked)
    test_java_version_active
    test_javac_version_active
    check_java_version_active_vs_dot
    check_javac_version_active_vs_dot

    # Compile Hello World
    javac $HELLO_WORLD
    rq=$?
    if [ $rq -ne 0 ]; then
        echo "Java Compiler failed"
        exit 6
    else
        echo "Java Compiler: PASS"
    fi

    # JVM is unable to load the *.class file unless you are into
    # the very same directory that the file exist 
    cd $DIR; java Hello > /dev/null
    rq=$?
    if [ $rq -ne 0 ]; then
        echo "Java failed to run the program"
        exit 7
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
