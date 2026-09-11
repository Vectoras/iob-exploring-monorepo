package main

import (
	"encoding/json"
	"log"
	"net"
	"net/http"

	"github.com/Vectoras/iob-exploring-monorepo/apps/api-go-name-generator/internal/utils"
	gotypes "github.com/Vectoras/iob-exploring-monorepo/packages/go-types"
	ung "github.com/dillonstreator/go-unique-name-generator"
	"github.com/dillonstreator/go-unique-name-generator/dictionaries"
	"github.com/google/uuid"
)

func main() {
	nameGenerator := ung.NewUniqueNameGenerator(
		ung.WithDictionaries([][]string{dictionaries.Adjectives, dictionaries.Animals}),
		ung.WithSeparator(" "),
		ung.WithStyle(ung.Capital),
	)
	nicknameGenerator := ung.NewUniqueNameGenerator(
		ung.WithDictionaries([][]string{dictionaries.Names}),
		ung.WithStyle(ung.Capital),
	)

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(http.StatusText(http.StatusOK)))
	})
	mux.HandleFunc("/random-user", func(w http.ResponseWriter, r *http.Request) {
		responseData, err := json.Marshal(gotypes.User{
			ID:       uuid.NewString(),
			Name:     nameGenerator.Generate(),
			Nickname: utils.Ptr(nicknameGenerator.Generate()),
		})
		if err != nil {
			log.Printf("Error marshalling JSON: %s", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(responseData))
	})

	const port = "8080"
	srv := &http.Server{
		Addr:    net.JoinHostPort("", port),
		Handler: mux,
	}
	log.Printf("server listening on port %s\n", port)
	log.Fatal(srv.ListenAndServe())
}
