ARG nodeVersion=
FROM node:${nodeVersion}
ARG pnpmVersion=
ARG goVersion=
ARG golangciVersion=
ARG cacheDir=
ARG TARGETARCH

ENV GOPATH="${cacheDir}/go"
ENV GOCACHE="${cacheDir}/go-build"
ENV PATH="$PATH:/usr/local/go/bin"
ENV PATH="$PATH:$GOPATH/bin"

RUN npm install -g pnpm@${pnpmVersion}

RUN  curl -fsSL https://go.dev/dl/go${goVersion}.linux-${TARGETARCH}.tar.gz | tar -C /usr/local -xz
RUN curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b /usr/local/bin v${golangciVersion}

USER node
