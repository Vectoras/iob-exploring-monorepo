# The image with everything: every toolchain of the repo (Node, pnpm, Go, the Go linter).
# For the services where work is done or prepared: `workspace` and `install`.
#
# Every version comes from compose.yaml as a build argument. The arguments have no
# defaults on purpose: a build that does not pass them fails instead of picking a version.

# Declared before FROM so they can be used in the base image's tag.
ARG NODE_VERSION=
ARG OS_RELEASE=
FROM node:${NODE_VERSION}-${OS_RELEASE}
ARG PNPM_VERSION=
ARG GO_VERSION=
ARG GOLANGCI_VERSION=
ARG CACHE_DIR=
# Set by Docker to the architecture being built for (amd64, arm64).
ARG TARGETARCH

# Go's module and build caches live in the bind-mounted repo, so they survive the
# container and are shared by every service. $GOPATH/bin is where `go install` puts tools.
ENV GOPATH="${CACHE_DIR}/go"
ENV GOCACHE="${CACHE_DIR}/go-build"
ENV PATH="$PATH:/usr/local/go/bin"
ENV PATH="$PATH:$GOPATH/bin"
# Only the Go this image installs is ever used. If the Go files ask for a newer one,
# Go fails instead of downloading another toolchain. Same in go.Dockerfile.
ENV GOTOOLCHAIN=local

# Installed directly at the pinned version, not through Corepack.
RUN npm install -g pnpm@${PNPM_VERSION}

# Go from its official archive, unpacked to /usr/local/go.
RUN  curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz | tar -C /usr/local -xz
# The Go linter as a released binary, as its documentation asks, not as a Go tool dependency.
RUN curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b /usr/local/bin v${GOLANGCI_VERSION}

# The non-root user that the Node image provides (id 1000). Files created in the
# bind mount get this owner, so every image has to run as the same id.
USER node
