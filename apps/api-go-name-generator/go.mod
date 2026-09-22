module github.com/Vectoras/iob-exploring-monorepo/apps/api-go-name-generator

go 1.26.1

require github.com/dillonstreator/go-unique-name-generator v1.0.2

require (
	github.com/Vectoras/iob-exploring-monorepo/packages/go-types v0.0.0-00010101000000-000000000000
	github.com/danielgtaylor/huma/v2 v2.39.1
	github.com/go-chi/chi/v5 v5.3.2
	github.com/go-chi/cors v1.2.2
	github.com/google/uuid v1.6.0
)

require (
	github.com/bokwoon95/wgo v0.7.1 // indirect
	github.com/fsnotify/fsnotify v1.10.1 // indirect
	github.com/fxamacker/cbor/v2 v2.9.2 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	golang.org/x/sys v0.47.0 // indirect
)

replace github.com/Vectoras/iob-exploring-monorepo/packages/go-types => ../../packages/go-types

tool github.com/bokwoon95/wgo
