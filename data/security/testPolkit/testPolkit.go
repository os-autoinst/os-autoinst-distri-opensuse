package main

import (
	"fmt"
	"log"
	"os"
	"os/user"
	"strconv"
	"syscall"

	"testPolkit/tap"
	"testPolkit/utils"
)

const (
	polkitRulesDir = "/etc/polkit-1/rules.d/"
	testRuleFile   = "/etc/polkit-1/rules.d/42-integration-test.rules"
	newHostname    = "polkit-test-hostname"
	tapOutputFile  = "testPolkit.tap"
	testUser       = "bernhard"
)

const polkitRule = `
// This is an example. Do not use this in production.
// This rule lets any user change the hostname without authentication
polkit.addRule(function(action, subject) {
	if (action.id == "org.freedesktop.hostname1.set-static-hostname") {
			return polkit.Result.YES;
		}
});
`

func main() {
	log.Println("Starting Polkit integration test...")

	testCases := map[int]tap.TestCase{
		1: {"Save original hostname", nil},
		2: {"Check polkit rules directory permissions (root:polkitd)", checkPermissions},
		3: {"Add polkit rule and restart service", addRuleAndRestart},
		4: {"Change hostname without authentication", changeHostnameWithAuth},
		5: {"Verify hostname was changed", verifyHostnameChanged},
		6: {"Remove polkit rule and restart service", removeRuleAndRestart},
		7: {"Hostname change should fail without authentication", changeHostnameShouldFail},
		8: {"Verify hostname was not changed", verifyHostnameUnchanged},
		9: {"Restore original hostname", nil},
	}

	tap, err := tap.NewTAPRunner(tapOutputFile, testCases)
	if err != nil {
		log.Fatalf("FATAL: Could not create TAP output file: %v", err)
	}
	defer tap.Close()

	// Save original hostname
	originalHostname, ok := saveOriginalHostname(tap)
	if !ok {
		return
	}
	// Defer the restoration of the original hostname
	defer func() {
		restoreHostname(originalHostname, tap)
	}()
	log.Printf("TAP output will be written to %s", tapOutputFile)

	tap.RunTests()

	log.Println("Polkit integration test completed successfully!")
}

// checkPermissions checks the permissions of the polkit rules directory
func checkPermissions(t *tap.TAPRunner) bool {
	log.Println("- Checking permissions for", polkitRulesDir)

	info, err := os.Stat(polkitRulesDir)
	if err != nil {
		return t.Bail(fmt.Sprintf("Could not stat %s: %v", polkitRulesDir, err))
	}

	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return t.Bail(fmt.Sprintf("Could not get file stat for %s", polkitRulesDir))
	}

	// Check owner is root (uid 0)
	if stat.Uid != 0 {
		return t.Fail(fmt.Sprintf("Owner of %s is not root (UID 0). Found UID: %d", polkitRulesDir, stat.Uid))
	}

	// Check group is polkitd
	polkitdGroup, err := user.LookupGroup("polkitd")
	if err != nil {
		return t.Fail(fmt.Sprintf("Could not look up group 'polkitd': %v. This test requires the 'polkitd' group to exist.", err))
	}
	polkitdGid, _ := strconv.Atoi(polkitdGroup.Gid)
	if stat.Gid != uint32(polkitdGid) {
		return t.Fail(fmt.Sprintf("Group of %s is not 'polkitd'. Expected GID: %d, Found GID: %d", polkitRulesDir, polkitdGid, stat.Gid))
	}

	return t.Pass()
}

// saveOriginalHostname saves the original hostname
func saveOriginalHostname(t *tap.TAPRunner) (string, bool) {
	log.Println("- Saving original hostname.")

	originalHostname, err := os.Hostname()
	if err != nil {
		t.Fail(fmt.Sprintf("Could not get original hostname: %v", err))
		return "", false
	}

	log.Println("Original hostname is:", originalHostname)
	t.Pass()
	return originalHostname, true
}

// addRuleAndRestart adds the polkit rule and restarts the service
func addRuleAndRestart(t *tap.TAPRunner) bool {
	log.Println("- Adding test polkit rule to", testRuleFile)

	if err := os.WriteFile(testRuleFile, []byte(polkitRule), 0644); err != nil {
		return t.Fail(fmt.Sprintf("Failed to write polkit rule file: %v. Make sure you are running this test as root.", err))
	}

	log.Println("Restarting polkit service...")
	result := utils.RunCommandTimeout(utils.MediumTimeout, "systemctl", "restart", "polkit")
	if result.Error != nil {
		diagnostic := fmt.Sprintf("Exit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			result.ExitCode, result.Error, result.Stdout, result.Stderr)
		return t.Fail(diagnostic)
	}

	return t.Pass()
}

// changeHostnameWithAuth attempts to change hostname (should succeed with polkit rule)
func changeHostnameWithAuth(t *tap.TAPRunner) bool {
	log.Printf("- Attempting to change hostname to %s as user %s (should succeed without password).", newHostname, testUser)

	result := utils.RunCommandTimeout(utils.MediumTimeout, "sudo", "-u", testUser, "hostnamectl", "set-hostname", newHostname)
	if result.Error != nil {
		diagnostic := fmt.Sprintf("Exit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			result.ExitCode, result.Error, result.Stdout, result.Stderr)
		return t.Fail(diagnostic)
	}

	return t.Pass()
}

// verifyHostnameChanged verifies that the hostname was actually changed
func verifyHostnameChanged(t *tap.TAPRunner) bool {
	log.Println("- Verifying hostname change.")

	currentHostname, _ := os.Hostname()
	if currentHostname != newHostname {
		return t.Fail(fmt.Sprintf("Hostname was not changed. Expected '%s', but found '%s'", newHostname, currentHostname))
	}

	return t.Pass()
}

// removeRuleAndRestart removes the polkit rule and restarts the service
func removeRuleAndRestart(t *tap.TAPRunner) bool {
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
	result := utils.RunCommandTimeout(utils.MediumTimeout, "systemctl", "restart", "polkit")
	if result.Error != nil {
		diagnostic := fmt.Sprintf("Exit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			result.ExitCode, result.Error, result.Stdout, result.Stderr)
		return t.Fail(diagnostic)
	}

	return t.Pass()
}

// changeHostnameShouldFail attempts to change hostname (should fail without polkit rule)
func changeHostnameShouldFail(t *tap.TAPRunner) bool {
	log.Printf("- Attempting to change hostname to 'should-fail-hostname' as user %s (should fail or ask for password).", testUser)

	// We expect this to fail because it will require authentication, which we can't provide.
	// The command will either timeout or return an error.
	result := utils.RunCommandTimeout(utils.ShortTimeout, "sudo", "-u", testUser, "hostnamectl", "set-hostname", "should-fail-hostname")
	if result.Error == nil {
		return t.Fail("Changing hostname succeeded when it should have failed")
	}

	if result.ExitCode != -1 {
		return t.Fail(fmt.Sprintf("Unexpected exit code: %d error : %s", result.ExitCode, result.Error))
	}
	return t.Pass()
}

// verifyHostnameUnchanged verifies that the hostname was NOT changed in the previous step
func verifyHostnameUnchanged(t *tap.TAPRunner) bool {
	log.Println("- Verifying hostname has not been changed.")

	currentHostname, _ := os.Hostname()
	if currentHostname != newHostname {
		return t.Fail(fmt.Sprintf("Hostname was changed when it should not have been. Expected '%s', but found '%s'", newHostname, currentHostname))
	}
	return t.Pass()
}

// restoreHostname restores the machine's original hostname
func restoreHostname(hostname string, t *tap.TAPRunner) {
	log.Println("- Restoring original hostname to", hostname)

	// This command needs to be run because the test might have failed,
	// leaving the system in a state where permissions are messed up.
	result := utils.RunCommandTimeout(utils.MediumTimeout, "hostnamectl", "set-hostname", hostname)
	if result.Error != nil {
		diagnostic := fmt.Sprintf("Failed to restore original hostname '%s'\nExit code: %d\nError: %v\nStdout: %s\nStderr: %s",
			hostname, result.ExitCode, result.Error, result.Stdout, result.Stderr)
		t.Fail(diagnostic)
		log.Printf("ERROR: Please restore hostname manually to: %s", hostname)
	} else {
		t.Pass()
	}
}
