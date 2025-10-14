package tap

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
	file      *os.File
	testCases map[int]TestCase
}

// NewTAPRunner creates a new TAP writer and test runner
func NewTAPRunner(filename string, testCases map[int]TestCase) (*TAPRunner, error) {
	file, err := os.Create(filename)
	if err != nil {
		return nil, err
	}

	writer := &TAPRunner{
		file:      file,
		testCases: testCases,
	}

	// Write TAP version and test plan
	fmt.Fprintf(file, "%s ..\n", filename)
	fmt.Fprintf(file, "1..%d\n", len(testCases))

	return writer, nil
}

// RunTests executes all the test cases when the function is not nil
func (w *TAPRunner) RunTests() {
	for i := 1; i <= len(w.testCases); i++ {
		tc := w.testCases[i]
		if tc.TestFunc != nil {
			if !tc.TestFunc(w) {
				return // Stop on first failure
			}
		}
	}
}

// Close closes the TAP writer
func (w *TAPRunner) Close() error {
	return w.file.Close()
}

// Pass writes a passing test result
func (w *TAPRunner) Pass(testNum int) {
	description := w.testCases[testNum].Description
	fmt.Fprintf(w.file, "ok %d - %s\n", testNum, description)
	log.Printf("PASS: Test %d - %s", testNum, description)
}

// Fail writes a failing test result with diagnostic information
func (w *TAPRunner) Fail(testNum int, diagnostic string) {
	description := w.testCases[testNum].Description
	fmt.Fprintf(w.file, "not ok %d - %s\n", testNum, description)
	if diagnostic != "" {
		// TAP diagnostics are prefixed with #
		lines := strings.Split(diagnostic, "\n")
		for _, line := range lines {
			if strings.TrimSpace(line) != "" {
				fmt.Fprintf(w.file, "# %s\n", line)
			}
		}
	}
	log.Printf("FAIL: Test %d - %s", testNum, description)
	if diagnostic != "" {
		log.Printf("DIAGNOSTIC: %s", diagnostic)
	}
}

// Skip writes a skipped test result
func (w *TAPRunner) Skip(testNum int, reason string) {
	description := w.testCases[testNum].Description
	fmt.Fprintf(w.file, "ok %d - %s # SKIP %s\n", testNum, description, reason)
	log.Printf("SKIP: Test %d - %s (reason: %s)", testNum, description, reason)
}

// Bail writes a bail out message and exits
func (w *TAPRunner) Bail(reason string) {
	fmt.Fprintf(w.file, "Bail out! %s\n", reason)
	w.Close()
	log.Fatalf("BAIL OUT: %s", reason)
}

// WriteComment writes a comment line to the TAP output
func (w *TAPRunner) WriteComment(comment string) {
	fmt.Fprintf(w.file, "# %s\n", comment)
}
