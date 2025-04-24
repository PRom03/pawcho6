# syntax=docker/dockerfile:1.4

FROM alpine AS builder

ARG VERSION=1.0.0

RUN apk add --no-cache go gcc musl-dev git openssh

WORKDIR /app
RUN mkdir -p /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN --mount=type=ssh git clone git@github.com:prom03/pawcho6.git .

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

FROM nginx:latest

WORKDIR /

COPY --from=builder /app/server /server
COPY nginx.conf /etc/nginx/nginx.conf

RUN chmod +x /server

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl -f http://localhost:8080/ || exit 1

CMD ["/bin/sh", "-c", "/server & sleep 2 && nginx -g 'daemon off;'"]
