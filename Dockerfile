# ---- Build stage ----
# Use the official Go image to compile a static binary.
# We pin a specific version to keep builds reproducible.
FROM golang:1.26-alpine AS build

WORKDIR /src

# Copy go.mod first to leverage Docker layer caching.
# If go.mod doesn't change, Docker reuses the dependency layer.
COPY go.mod ./
# (No go.sum yet because we have zero external deps. Add this line back later:
#  COPY go.sum ./
#  when you add dependencies.)

RUN go mod download

# Copy the rest of the source.
COPY ./ ./

# CGO_ENABLED=0 produces a fully static binary that runs on any Linux without
# glibc. This is what lets us use the tiny "scratch" base image below.
# -ldflags="-s -w" strips debug info to shrink the binary further.
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/api .

# ---- Runtime stage ----
# "scratch" is literally an empty image — no shell, no package manager, no OS
# tools. The smallest possible attack surface. The downside: you can't `docker
# exec` into it to debug. If you want a shell for debugging, swap to
# "gcr.io/distroless/static-debian12" or "alpine:3.20".
FROM scratch

# Copy the static binary from the build stage.
COPY --from=build /out/api /api

# Run as a non-root user (UID 65532 is the "nobody" user reserved for this).
# Containers running as root are a security anti-pattern and ECS/EKS security
# scans will flag it.
USER 65532:65532

# Document the port the app listens on. EXPOSE is metadata only — it doesn't
# actually open the port. The orchestrator (Docker, ECS, EKS) decides that.
EXPOSE 8080

ENTRYPOINT ["/api"]
