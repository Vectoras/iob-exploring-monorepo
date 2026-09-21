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
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
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

	router := chi.NewRouter()

	router.Use(middleware.Logger)
	router.Use(middleware.Heartbeat("/healthz"))
	router.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"http://localhost:*", "http://127.0.0.1:*"},
		AllowedMethods: []string{"GET"},
		AllowedHeaders: []string{"Content-Type"},
	}))

	router.Get("/random-user", func(w http.ResponseWriter, r *http.Request) {
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
		_, _ = w.Write(responseData)
	})

	const port = "3006"
	srv := &http.Server{
		Addr:    net.JoinHostPort("", port),
		Handler: router,
	}
	log.Printf("server listening on port %s\n / http://localhost:%s\n", port, port)
	log.Fatal(srv.ListenAndServe())
}
