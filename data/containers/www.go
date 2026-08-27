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
	files := http.FileServer(http.Dir("/srv/www/htdocs"))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("http request from %s: %s %s", r.RemoteAddr, r.Method, r.URL.Path)
		files.ServeHTTP(w, r)
	})
	log.Printf("http serving on %s:%s", addr, port)
	log.Fatal(http.ListenAndServe(addr+":"+port, nil))
}
