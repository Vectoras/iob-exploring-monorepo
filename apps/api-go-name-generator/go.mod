module github.com/Vectoras/iob-exploring-monorepo/apps/api-go-name-generator

go 1.26.1

require github.com/dillonstreator/go-unique-name-generator v1.0.2

require (
	github.com/Vectoras/iob-exploring-monorepo/packages/go-types v0.0.0-00010101000000-000000000000
	github.com/google/uuid v1.6.0
)

require (
	github.com/bokwoon95/wgo v0.7.1 // indirect
	github.com/fsnotify/fsnotify v1.10.1 // indirect
	golang.org/x/sys v0.47.0 // indirect
)

replace github.com/Vectoras/iob-exploring-monorepo/packages/go-types => ../../packages/go-types

tool github.com/bokwoon95/wgo
