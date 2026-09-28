ARG NODE_VERSION=
FROM node:${NODE_VERSION}
ARG PNPM_VERSION=
ARG GO_VERSION=
ARG GOLANGCI_VERSION=
ARG CACHE_DIR=
ARG TARGETARCH

ENV GOPATH="${CACHE_DIR}/go"
ENV GOCACHE="${CACHE_DIR}/go-build"
ENV PATH="$PATH:/usr/local/go/bin"
ENV PATH="$PATH:$GOPATH/bin"

RUN npm install -g pnpm@${PNPM_VERSION}

RUN  curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz | tar -C /usr/local -xz
RUN curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b /usr/local/bin v${GOLANGCI_VERSION}

USER node
