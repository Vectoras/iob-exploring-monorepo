# The Go image: the Go toolchain and nothing else. No Node, no pnpm, no linter.
# For the services that only run a Go app.
#
# Every version comes from compose.yaml as a build argument. The arguments have no
# defaults on purpose: a build that does not pass them fails instead of picking a version.

# Declared before FROM so they can be used in the base image's tag.
# Same Go version and same OS release as all.Dockerfile: Go tools are
# built there by `install` and run here from the shared cache.
ARG GO_VERSION=
ARG OS_RELEASE=
FROM golang:${GO_VERSION}-${OS_RELEASE}
ARG CACHE_DIR=

# Go's module and build caches live in the bind-mounted repo, so they survive the
# container and are shared by every service. Same paths as in all.Dockerfile.
ENV GOPATH="${CACHE_DIR}/go"
ENV GOCACHE="${CACHE_DIR}/go-build"
ENV PATH="$PATH:$GOPATH/bin"
# Only the Go this image installs is ever used. If the Go files ask for a newer one,
# Go fails instead of downloading another toolchain. Go's image already sets this;
# written here so it does not depend on the base image. Same in all.Dockerfile.
ENV GOTOOLCHAIN=local

# The Go image only has root. Files created in the bind mount must have the same owner
# as in all.Dockerfile, whose user (from the Node image) has id 1000.
RUN useradd --create-home --uid 1000 --shell /bin/bash go

USER go
