# syntax=docker/dockerfile:1.4

FROM alpine AS builder

ARG VERSION=1.0.0

# Potrzebne do budowania i klonowania repozytorium przez SSH
RUN apk add --no-cache go gcc musl-dev git openssh

# Mount SSH key i sklonuj repo przez SSH
WORKDIR /app

# SSH mount: pozwala na użycie klucza SSH hosta w kontenerze
RUN --mount=type=ssh \
    git clone git@github.com:prom03/pawcho6 /app

# Budowanie aplikacji
RUN echo 'package main' > main.go \
    && echo 'import ("fmt"; "net/http"; "os"; "net")' >> main.go \
    && echo 'var Version = "unknown"' >> main.go \
    && echo 'func handler(w http.ResponseWriter, r *http.Request) {' >> main.go \
    && echo '    hostname, _ := os.Hostname()' >> main.go \
    && echo '    ip, _ := net.LookupIP(hostname)' >> main.go \
    && echo '    fmt.Fprintf(w, "Server IP: %v\n", ip)' >> main.go \
    && echo '    fmt.Fprintf(w, "Hostname: %s\n", hostname)' >> main.go \
    && echo '    fmt.Fprintf(w, "Version: %s\n", Version)' >> main.go \
    && echo '}' >> main.go \
    && echo 'func main() { http.HandleFunc("/", handler); http.ListenAndServe(":8080", nil) }' >> main.go

RUN CGO_ENABLED=0 go build -ldflags "-X main.Version=${VERSION} -extldflags '-static'" -o server main.go

# Finalny obraz z nginx
FROM nginx:latest

WORKDIR /

COPY --from=builder /app/server /server
COPY nginx.conf /etc/nginx/nginx.conf

RUN chmod +x /server

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl -f http://localhost:8080/ || exit 1

CMD ["/bin/sh", "-c", "/server & sleep 2 && nginx -g 'daemon off;'"]
