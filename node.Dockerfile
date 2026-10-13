# The Node image: Node and pnpm, nothing else. No Go, no compilers, no git.
# For the services that only run a Node app. Built on the slim variant of the Node
# image: dependencies are installed by `maintenance` in all.Dockerfile, and these
# services only run what is already in node_modules.
#
# Every version comes from compose.yaml as a build argument. The arguments have no
# defaults on purpose: a build that does not pass them fails instead of picking a version.

# Declared before FROM so they can be used in the base image's tag.
# Same Node version and same OS release as all.Dockerfile: the programs in
# node_modules are installed there and run here.
ARG NODE_VERSION=
ARG OS_RELEASE=
FROM node:${NODE_VERSION}-${OS_RELEASE}-slim
ARG PNPM_VERSION=

# Installed directly at the pinned version, not through Corepack. The apps are
# started with `pnpm run <script>`.
RUN npm install -g pnpm@${PNPM_VERSION}

# The non-root user that the Node image provides (id 1000), the same id as in the
# other images, so files created in the bind mount have the same owner everywhere.
USER node
