# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Description: Basic Ant test
# Summary: Runs an ant build file that compiles a sample java code,
#          creates a jar file and runs it.
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

my $java_hello_world = <<'EOF';
package test;

public class Hello{
     public static void main (String argv[]){
         System.out.println("Hello World");
     }
}
EOF

my $build_file_xml = <<'EOF';
<project name="Hello" basedir="." default="main">

    <property name="src.dir"     value="src"/>

    <property name="build.dir"   value="build"/>
    <property name="classes.dir" value="${build.dir}/classes"/>
    <property name="jar.dir"     value="${build.dir}/jar"/>

    <property name="main-class"  value="test.Hello"/>



    <target name="clean">
        <echo>***Cleaning the build directory***</echo>
        <delete dir="${build.dir}"/>
    </target>

    <target name="compile">
        <echo>***Compiling***</echo>
        <mkdir dir="${classes.dir}"/>
        <javac includeantruntime="false" srcdir="${src.dir}" destdir="${classes.dir}"/>
    </target>

    <target name="jar" depends="compile">
        <echo>***Creating jar file***</echo>
        <mkdir dir="${jar.dir}"/>
        <jar destfile="${jar.dir}/${ant.project.name}.jar" basedir="${classes.dir}">
            <manifest>
                <attribute name="Main-Class" value="${main-class}"/>
            </manifest>
        </jar>
    </target>

    <target name="run" depends="jar">
        <echo>***Running jar file***</echo>
        <java jar="${jar.dir}/${ant.project.name}.jar" fork="true"/>
    </target>

    <target name="clean-build" depends="clean,jar"/>

    <target name="main" depends="clean,run"/>

</project>
EOF


sub run {
    my $dir = "/root/ant_test";

    select_console 'root-console';

    # Install ant
    zypper_call 'in ant';

    # Set JAVA_HOME to the jdk installation directory
    assert_script_run("export JAVA_HOME=`update-alternatives --list javac| awk -F 'java' '{split(\$0, a); print a[1]; exit}'`'java'");
    assert_script_run("export ANT_HOME=/usr/share/ant");

    # Set up
    assert_script_run "mkdir $dir";
    assert_script_run "cd $dir";
    assert_script_run "mkdir -p src/test";
    assert_script_run "mkdir -p build/classes";
    assert_script_run "echo '$java_hello_world' >> src/test/Hello.java";
    assert_script_run "echo '$build_file_xml' >> build.xml";

    # Check that ant builds succesfully
    assert_script_run "ant";
    # Check that ant runs the application succesfully
    assert_script_run 'ant run| grep "Hello World"';
}

1;
