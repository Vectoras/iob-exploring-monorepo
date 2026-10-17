module github.com/Vectoras/iob-exploring-monorepo/apps/api-go-name-generator

go 1.27.2

require (
	github.com/Vectoras/iob-exploring-monorepo/packages/go-types v0.0.0-00010101000000-000000000000
	github.com/danielgtaylor/huma/v2 v2.39.1
	github.com/dillonstreator/go-unique-name-generator v1.0.2
	github.com/go-chi/chi/v5 v5.3.2
	github.com/go-chi/cors v1.2.2
	github.com/google/uuid v1.6.0
)

require (
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
)

replace github.com/Vectoras/iob-exploring-monorepo/packages/go-types => ../../packages/go-types
