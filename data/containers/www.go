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
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("http request from %s: %s %s", r.RemoteAddr, r.Method, r.URL.Path)
		_, _ = w.Write([]byte("<html>The test shall pass</html>"))
	})
	log.Printf("http serving on %s:%s", addr, port)
	log.Fatal(http.ListenAndServe(addr+":"+port, nil))
}
