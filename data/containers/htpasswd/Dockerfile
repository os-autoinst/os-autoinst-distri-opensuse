FROM registry.opensuse.org/opensuse/bci/golang:latest as builder

WORKDIR /go/src/htpasswd

COPY main.go .
COPY go.* .

RUN go build -o /htpasswd

FROM scratch

COPY --from=builder /htpasswd /

ENTRYPOINT ["/htpasswd"]
