module github.com/Vectoras/iob-exploring-monorepo/apps/api-go-name-generator

go 1.26.1

require github.com/dillonstreator/go-unique-name-generator v1.0.2

require (
	github.com/Vectoras/iob-exploring-monorepo/packages/go-types v0.0.0-00010101000000-000000000000
	github.com/google/uuid v1.6.0
)

replace github.com/Vectoras/iob-exploring-monorepo/packages/go-types => ../../packages/go-types
