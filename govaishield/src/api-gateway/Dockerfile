# Multi-stage, non-root, distroless → imagem mínima e segura
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download || true
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w -X github.com/executt/govaishield/api-gateway/internal/handlers.Version=$(cat /src/VERSION 2>/dev/null || echo dev)" -o /out/api-gateway ./cmd/main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api-gateway /api-gateway
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api-gateway"]
