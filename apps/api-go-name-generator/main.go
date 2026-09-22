package main

import (
	"context"
	"log"
	"net"
	"net/http"

	gotypes "github.com/Vectoras/iob-exploring-monorepo/packages/go-types"
	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	ung "github.com/dillonstreator/go-unique-name-generator"
	"github.com/dillonstreator/go-unique-name-generator/dictionaries"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/google/uuid"
)

type RandomUserOutput struct {
	Body gotypes.User
}

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

	api := humachi.New(router, huma.DefaultConfig("@iob-exploring-monorepo/api-go-name-generator", "0.0.1"))

	huma.Register(api,
		huma.Operation{
			Method:      http.MethodGet,
			Path:        "/random-user",
			Summary:     "Generate a silly random user",
			Description: "Simple endpoint to generate a silly random user with an id, a username and a nickname, which arguably is the more normal one.",
		},
		func(ctx context.Context, i *struct{}) (*RandomUserOutput, error) {
			response := &RandomUserOutput{
				Body: gotypes.User{
					ID:       uuid.NewString(),
					Name:     nameGenerator.Generate(),
					Nickname: new(nicknameGenerator.Generate()),
				},
			}
			return response, nil
		},
	)

	const port = "3006"
	srv := &http.Server{
		Addr:    net.JoinHostPort("", port),
		Handler: router,
	}
	log.Printf("server listening on port %s (http://localhost:%s\n)", port, port)
	log.Fatal(srv.ListenAndServe())
}
