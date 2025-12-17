// SUSE's openQA tests
//
// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

package main

import (
	"log"
	"os"
	"os/user"
	"strconv"
	"syscall"

	"testing"
)

const (
	polkitRulesDir = "/etc/polkit-1/rules.d/"
	testRuleFile   = "/etc/polkit-1/rules.d/42-integration-test.rules"
	newHostname    = "polkit-test-hostname"
	testUser       = "bernhard"
)

type testCase struct {
	Name     string
	Function func(t *testing.T)
}

const polkitRule = `
// This is an example. Do not use this in production.
// This rule lets any user change the hostname without authentication
polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.hostname1.set-static-hostname") {
                        return polkit.Result.YES;
                }
});
`

func TestPolkit(t *testing.T) {
	log.Println("Starting Polkit integration test...")

	// Save original hostname
	originalHostname, ok := saveOriginalHostname(t)
	if !ok {
		t.Error()
		return
	}
	testCases := []testCase{
		{"Check polkit rules directory permissions (root:polkitd)", checkPermissions},
		{"Add polkit rule and restart service", addRuleAndRestart},
		{"Change hostname without authentication", changeHostnameWithAuth},
		{"Verify hostname was changed", verifyHostnameChanged},
		{"Remove polkit rule and restart service", removeRuleAndRestart},
		{"Hostname change should fail without authentication", changeHostnameShouldFail},
		{"Verify hostname was not changed", verifyHostnameUnchanged},
	}

	for _, tc := range testCases {
		t.Run(tc.Name, func(t *testing.T) {
			tc.Function(t)
		})
	}
	restoreHostname(originalHostname, t)
}

// checkPermissions checks the permissions of the polkit rules directory
func checkPermissions(t *testing.T) {
	log.Println("- Checking permissions for", polkitRulesDir)

	info, err := os.Stat(polkitRulesDir)
	if err != nil {
		t.Fatalf("Could not stat %s: %v", polkitRulesDir, err)
	}

	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		t.Errorf("Could not get file stat for %s", polkitRulesDir)
	}

	// Check owner is root (uid 0)
	if stat.Uid != 0 {
		t.Errorf("Owner of %s is not root (UID 0). Found UID: %d", polkitRulesDir, stat.Uid)
	}

	// Check group is polkitd
	polkitdGroup, err := user.LookupGroup("polkitd")
	if err != nil {
		t.Errorf("Could not look up group 'polkitd': %v. This test requires the 'polkitd' group to exist.", err)
	}
	polkitdGid, _ := strconv.Atoi(polkitdGroup.Gid)
	if stat.Gid != uint32(polkitdGid) {
		t.Errorf("Group of %s is not 'polkitd'. Expected GID: %d, Found GID: %d", polkitRulesDir, polkitdGid, stat.Gid)
	}
}

// saveOriginalHostname saves the original hostname
func saveOriginalHostname(t *testing.T) (string, bool) {
	log.Println("- Saving original hostname.")

	originalHostname, err := os.Hostname()
	if err != nil {
		t.Errorf("Could not get original hostname: %v", err)
	}
	log.Println("Original hostname is:", originalHostname)
	return originalHostname, true
}

// addRuleAndRestart adds the polkit rule and restarts the service
func addRuleAndRestart(t *testing.T) {
	log.Println("- Adding test polkit rule to", testRuleFile)

	if err := os.WriteFile(testRuleFile, []byte(polkitRule), 0644); err != nil {
		t.Errorf("Failed to write polkit rule file: %v. Make sure you are running this test as root.", err)
	}

	log.Println("Restarting polkit service...")
	result := RunCommandTimeout(MediumTimeout, "systemctl", "restart", "polkit")
	if result.Error != nil {
		t.Errorf("Exit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			result.ExitCode, result.Error, result.Stdout, result.Stderr)
	}
}

// changeHostnameWithAuth attempts to change hostname (should succeed with polkit rule)
func changeHostnameWithAuth(t *testing.T) {
	log.Printf("- Attempting to change hostname to %s as user %s (should succeed without password).", newHostname, testUser)

	result := RunCommandTimeout(MediumTimeout, "sudo", "-u", testUser, "hostnamectl", "set-hostname", newHostname)
	if result.Error != nil {
		t.Errorf("Exit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			result.ExitCode, result.Error, result.Stdout, result.Stderr)
	}
}

// verifyHostnameChanged verifies that the hostname was actually changed
func verifyHostnameChanged(t *testing.T) {
	log.Println("- Verifying hostname change.")

	currentHostname, _ := os.Hostname()
	if currentHostname != newHostname {
		t.Errorf("Hostname was not changed. Expected '%s', but found '%s'", newHostname, currentHostname)
	}
}

// removeRuleAndRestart removes the polkit rule and restarts the service
func removeRuleAndRestart(t *testing.T) {
	log.Println("- Removing test polkit rule and restarting service.")

	// Clean up now to test the next step
	log.Println("Cleaning up test rule file:", testRuleFile)
	if err := os.Remove(testRuleFile); err != nil {
		// Log as a warning because the file might have been removed already.
		log.Printf("WARN: Could not remove test rule file %s: %v", testRuleFile, err)
	} else {
		log.Println("Test rule file removed.")
	}

	log.Println("Restarting polkit service...")
	result := RunCommandTimeout(MediumTimeout, "systemctl", "restart", "polkit")
	if result.Error != nil {
		t.Fatalf("Exit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			result.ExitCode, result.Error, result.Stdout, result.Stderr)
	}
}

// changeHostnameShouldFail attempts to change hostname (should fail without polkit rule)
func changeHostnameShouldFail(t *testing.T) {
	log.Printf("- Attempting to change hostname to 'should-fail-hostname' as user %s (should fail or ask for password).", testUser)

	// We expect this to fail because it will require authentication, which we can't provide.
	// The command will either timeout or return an error.
	result := RunCommandTimeout(ShortTimeout, "sudo", "-u", testUser, "hostnamectl", "set-hostname", "should-fail-hostname")
	if result.Error == nil {
		t.Error("Changing hostname succeeded when it should have failed")
	}

	if result.ExitCode != -1 {
		t.Errorf("Unexpected exit code: %d error : %s", result.ExitCode, result.Error)
	}
}

// verifyHostnameUnchanged verifies that the hostname was NOT changed in the previous step
func verifyHostnameUnchanged(t *testing.T) {
	log.Println("- Verifying hostname has not been changed.")

	currentHostname, _ := os.Hostname()
	if currentHostname != newHostname {
		t.Errorf("Hostname was changed when it should not have been. Expected '%s', but found '%s'", newHostname, currentHostname)
	}
}

// restoreHostname restores the machine's original hostname
func restoreHostname(hostname string, t *testing.T) {
	log.Println("- Restoring original hostname to", hostname)

	// This command needs to be run because the test might have failed,
	// leaving the system in a state where permissions are messed up.
	result := RunCommandTimeout(MediumTimeout, "hostnamectl", "set-hostname", hostname)
	if result.Error != nil {
		t.Errorf("Failed to restore original hostname '%s'\nExit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			hostname, result.ExitCode, result.Error, result.Stdout, result.Stderr)
		log.Printf("ERROR: Please restore hostname manually to: %s", hostname)
	} else {
		t.Log("Hostname restored successfully")
	}
}
