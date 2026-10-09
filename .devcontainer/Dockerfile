# Self-contained dev/CI image for eigenlua.
#
# eigenlua is a consumer of EigenScript: the front end will run .eigs programs
# against the runtime. This image builds EigenScript at a pinned tag and puts
# it on PATH, so the image is fully reproducible and the tag below IS the
# version pin — bump EIGS_REF to move the runtime under the suite.
#
# The same image backs Codespaces AND CI (.github/workflows/tests.yml runs the
# suite inside it via devcontainers/ci), so "green in my Codespace" and "green
# in CI" can't drift. Building from source (rather than FROM a published
# runtime image) keeps this working for a private repo with no cross-repo
# package-pull credentials.
#
# curl is here because tools/build_ref.sh downloads the pinned Lua tarball
# and builds it inside the image. Lua's `linux` target does not link readline.
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        time \
 && rm -rf /var/lib/apt/lists/*

# Build + install EigenScript at the pinned tag onto /usr/local (binary on
# PATH, stdlib at /usr/local/lib/eigenscript — found relative to the binary).
ARG EIGS_REF=v0.45.1
RUN git clone --depth 1 --branch "${EIGS_REF}" \
        https://github.com/InauguralSystems/EigenScript.git /tmp/eigs \
 && make -C /tmp/eigs install PREFIX=/usr/local CC=gcc \
 && rm -rf /tmp/eigs

WORKDIR /workspaces/eigenlua
