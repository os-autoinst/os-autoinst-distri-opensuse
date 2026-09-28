package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = "0.0.0.0"
	}
	http.Handle("/", http.FileServer(http.Dir("/srv/www/htdocs")))
	log.Printf("http serving on %s:%s", addr, port)
	log.Fatal(http.ListenAndServe(addr+":"+port, nil))
}
