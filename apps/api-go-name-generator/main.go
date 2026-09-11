package main

import (
	"log"
	"net"
	"net/http"

	ung "github.com/dillonstreator/go-unique-name-generator"
	"github.com/dillonstreator/go-unique-name-generator/dictionaries"
)

func main() {
	nameGenerator := ung.NewUniqueNameGenerator(
		ung.WithDictionaries([][]string{dictionaries.Adjectives, dictionaries.Animals}),
		ung.WithSeparator(" "),
		ung.WithStyle(ung.Capital),
	)

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(http.StatusText(http.StatusOK)))
	})
	mux.HandleFunc("/random-user", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(nameGenerator.Generate()))
	})

	const port = "8080"
	srv := &http.Server{
		Addr:    net.JoinHostPort("", port),
		Handler: mux,
	}
	log.Printf("server listening on port %s\n", port)
	log.Fatal(srv.ListenAndServe())
}
