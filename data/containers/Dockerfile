# Stage 1 builds a statically linked test server (CGO_ENABLED=0), so the final
# image needs no package manager, no interpreter and no particular glibc.
FROM builderimage_var AS build
ENV GOTOOLCHAIN=local
WORKDIR /src
COPY www.go .
RUN go mod init testapp && CGO_ENABLED=0 go build -o /www www.go

FROM baseimage_var
COPY --from=build /www /www
COPY index.html /srv/www/htdocs/index.html
EXPOSE 80
ENV WORLD_VAR Arda
ENTRYPOINT ["/www"]
