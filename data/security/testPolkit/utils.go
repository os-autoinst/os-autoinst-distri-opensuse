package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"syscall"
	"time"
)

// CommandResult represents the result of a command execution.
type CommandResult struct {
	Stdout   string
	Stderr   string
	Error    error
	ExitCode int
	Duration time.Duration
	TimedOut bool
}

// RunCommandTimeout executes a command with a specified timeout and returns a detailed result.
//
// Parameters:
//   - timeout: Maximum duration to wait for the command to complete.
//   - command: Variable number of strings representing the command and its arguments.
//
// If only one argument is provided, it's treated as a shell command.
// If multiple arguments are provided, the first is the command and the rest are arguments.
//
// Returns:
//   - A pointer to a CommandResult struct containing stdout, stderr, error, exit code, duration, and timeout status.
//
// Example usage:
//
//	// Direct command execution
//	result := RunCommandTimeout(5*time.Second, "echo", "hello", "world")
//	if result.Error != nil {
//	    log.Printf("Command failed with exit code %d: %v", result.ExitCode, result.Error)
//	}
//	fmt.Println(result.Stdout)
func RunCommandTimeout(timeout time.Duration, command ...string) *CommandResult {
	start := time.Now()

	if len(command) == 0 {
		return &CommandResult{
			Error:    fmt.Errorf("no command provided"),
			ExitCode: -1,
			Duration: time.Since(start),
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	var cmd *exec.Cmd
	if len(command) == 1 {
		cmd = exec.CommandContext(ctx, "sh", "-c", command[0])
	} else {
		cmd = exec.CommandContext(ctx, command[0], command[1:]...)
	}

	var outBuf, errBuf bytes.Buffer

	outPipe, _ := cmd.StdoutPipe()
	errPipe, _ := cmd.StderrPipe()

	// asincronously read stdout and stderr to our buffer
	// so we get something even if the command is killed by timeout
	go func() {
		io.Copy(&errBuf, errPipe)
		io.Copy(&outBuf, outPipe)
	}()

	err := cmd.Start()
	if err != nil {
		return &CommandResult{
			Stdout:   "",
			Stderr:   "",
			Error:    fmt.Errorf("failed to start command: %w", err),
			ExitCode: -1,
			Duration: time.Since(start),
			TimedOut: false,
		}
	}

	// Wait for command to finish or timeout
	err = cmd.Wait()
	duration := time.Since(start)
	timedOut := false
	exitCode := 0

	if ctx.Err() == context.DeadlineExceeded {
		timedOut = true
		exitCode = -1 // No exit code available for a timed-out process
		err = fmt.Errorf("command timed out after %v", timeout)
	} else if err != nil {
		// The command returned a non-zero exit code.
		if exitError, ok := err.(*exec.ExitError); ok {
			// The command started and exited with a non-zero exit code.
			exitCode = exitError.ExitCode()
		} else {
			// Other error occurred
			exitCode = -1
		}
	} else {
		// The command succeeded.
		if cmd.ProcessState != nil {
			if status, ok := cmd.ProcessState.Sys().(syscall.WaitStatus); ok {
				exitCode = status.ExitStatus()
			}
		}
	}

	return &CommandResult{
		Stdout:   outBuf.String(),
		Stderr:   errBuf.String(),
		Error:    err,
		ExitCode: exitCode,
		Duration: duration,
		TimedOut: timedOut,
	}
}

// Common timeout durations for convenience
const (
	// ShortTimeout is suitable for quick commands like 'echo', 'pwd', etc.
	ShortTimeout = 5 * time.Second

	// MediumTimeout is suitable for moderate operations like file operations, simple network calls
	MediumTimeout = 30 * time.Second

	// LongTimeout is suitable for longer operations like compilation, large file transfers
	LongTimeout = 5 * time.Minute
)

// RunCommandTimeoutShort executes a command with a short timeout (5 seconds).
// This is a convenience function for commands that should complete quickly.
func RunCommandTimeoutShort(command ...string) *CommandResult {
	return RunCommandTimeout(ShortTimeout, command...)
}

// RunCommandTimeoutMedium executes a command with a medium timeout (30 seconds).
// This is a convenience function for commands that may take moderate time.
func RunCommandTimeoutMedium(command ...string) *CommandResult {
	return RunCommandTimeout(MediumTimeout, command...)
}

// RunCommandTimeoutLong executes a command with a long timeout (5 minutes).
// This is a convenience function for commands that may take considerable time.
func RunCommandTimeoutLong(command ...string) *CommandResult {
	return RunCommandTimeout(LongTimeout, command...)
}

// IsCommandAvailable checks if a command is available in the system PATH.
// It returns true if the command can be executed, false otherwise.
func IsCommandAvailable(command string) bool {
	result := RunCommandTimeout(ShortTimeout, "which", command)
	return result.Error == nil && result.ExitCode == 0
}

// GetCommandOutput is a simple wrapper that returns only stdout and ignores stderr and errors.
// Use this when you only care about successful output and want to ignore errors.
// Returns empty string if the command fails.
func GetCommandOutput(timeout time.Duration, command ...string) string {
	result := RunCommandTimeout(timeout, command...)
	if result.Error != nil {
		return ""
	}
	return strings.TrimSpace(result.Stdout)
}
