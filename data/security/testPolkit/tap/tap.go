package tap

// a very simple test suite runner

import (
	"fmt"
	"log"
	"os"
	"strings"
)

// TestCase represents a single test step
type TestCase struct {
	Description string
	TestFunc    func(*TAPRunner) bool
}

// TAPRunner handles TAP output formatting and file writing
type TAPRunner struct {
	file        *os.File
	testCases   map[int]TestCase
	currentStep int
}

// NewTAPRunner creates a new TAP writer and test runner
func NewTAPRunner(filename string, testCases map[int]TestCase) (*TAPRunner, error) {
	file, err := os.Create(filename)
	if err != nil {
		return nil, err
	}

	tr := &TAPRunner{
		file:      file,
		testCases: testCases,
	}

	// Write TAP version and test plan
	fmt.Fprintf(file, "%s ..\n", filename)
	fmt.Fprintf(file, "1..%d\n", len(testCases))

	return tr, nil
}

// RunTests executes all the test cases when the function is not nil
func (t *TAPRunner) RunTests() {
	for i := 1; i <= len(t.testCases); i++ {
		tc := t.testCases[i]
		if tc.TestFunc == nil {
			continue // nothing to do
		}
		prevStep := t.currentStep
		result := tc.TestFunc(t)
		// give message if function didn't call Fail() or Pass()
		if t.currentStep == prevStep {
			log.Printf("ERROR: Missing FAIL or PASS in step function %d - %s", prevStep, tc.Description)
			return
		}
		if !result {
			return // Stop on first failure
		}
	}
}

// Close closes the TAP writer
func (t TAPRunner) Close() error {
	return t.file.Close()
}

// Pass writes a passing test result
func (t *TAPRunner) Pass() bool {
	t.currentStep++
	description := t.testCases[t.currentStep].Description
	fmt.Fprintf(t.file, "ok %d - %s\n", t.currentStep, description)
	log.Printf("PASS: Test %d - %s", t.currentStep, description)
	return true
}

// Fail writes a failing test result with diagnostic information
func (t *TAPRunner) Fail(diagnostic string) bool {
	t.currentStep++
	description := t.testCases[t.currentStep].Description
	fmt.Fprintf(t.file, "not ok %d - %s\n", t.currentStep, description)
	if diagnostic != "" {
		// TAP diagnostics are prefixed with #
		lines := strings.Split(diagnostic, "\n")
		for _, line := range lines {
			if strings.TrimSpace(line) != "" {
				fmt.Fprintf(t.file, "# %s\n", line)
			}
		}
	}
	log.Printf("FAIL: Test %d - %s", t.currentStep, description)
	if diagnostic != "" {
		log.Printf("DIAGNOSTIC: %s", diagnostic)
	}
	return false
}

// Bail writes a bail out message and exits
func (t *TAPRunner) Bail(reason string) bool {
	fmt.Fprintf(t.file, "Bail out! %s\n", reason)
	t.Close()
	log.Fatalf("BAIL OUT: %s", reason)
	return false
}
