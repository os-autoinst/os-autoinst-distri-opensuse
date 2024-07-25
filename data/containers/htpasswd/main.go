package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
	"os"
	"strings"
)

func main() {
	if len(os.Args) != 4 || os.Args[1] != "-Bbn" {
		fmt.Println("Usage: " + os.Args[0] + " -Bbn username password")
		os.Exit(1)
	}
	username := os.Args[2]
	password := os.Args[3]

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		panic(err)
	}

	digest := string(hash)
	digest = "$2y" + strings.TrimPrefix(digest, "$2a")
	fmt.Printf("%s:%s\n\n", username, digest)
}
