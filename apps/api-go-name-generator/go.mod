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
	github.com/bokwoon95/wgo v0.7.1 // indirect
	github.com/cilium/ebpf v0.22.0 // indirect
	github.com/clipperhouse/uax29/v2 v2.7.0 // indirect
	github.com/cosiner/argv v0.1.0 // indirect
	github.com/cpuguy83/go-md2man/v2 v2.0.6 // indirect
	github.com/derekparker/trie/v3 v3.2.0 // indirect
	github.com/fsnotify/fsnotify v1.10.1 // indirect
	github.com/fxamacker/cbor/v2 v2.9.2 // indirect
	github.com/go-delve/delve v1.27.2 // indirect
	github.com/go-delve/liner v1.2.3-0.20231231155935-4726ab1d7f62 // indirect
	github.com/google/go-dap v0.12.0 // indirect
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/mattn/go-colorable v0.1.15 // indirect
	github.com/mattn/go-isatty v0.0.23 // indirect
	github.com/mattn/go-runewidth v0.0.24 // indirect
	github.com/russross/blackfriday/v2 v2.1.0 // indirect
	github.com/spf13/cobra v1.10.2 // indirect
	github.com/spf13/pflag v1.0.10 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	go.starlark.net v0.0.0-20231101134539-556fd59b42f6 // indirect
	go.yaml.in/yaml/v3 v3.0.4 // indirect
	golang.org/x/arch v0.29.0 // indirect
	golang.org/x/sync v0.22.0 // indirect
	golang.org/x/sys v0.47.0 // indirect
	golang.org/x/telemetry v0.0.0-20241106142447-58a1122356f5 // indirect
)

replace github.com/Vectoras/iob-exploring-monorepo/packages/go-types => ../../packages/go-types

tool (
	github.com/bokwoon95/wgo
	github.com/go-delve/delve/cmd/dlv
)
