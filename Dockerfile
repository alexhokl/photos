FROM golang:1.25.5-alpine3.21 AS builder

RUN apk add --no-cache gcc musl-dev libjpeg-turbo-dev wget

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=1 go build -o photos .

# Build dcraw from source (not available as an Alpine package).
# -DNO_JASPER omits JPEG-2000/Cinerama support (jasper not in Alpine).
# -DNO_LCMS omits colour profile support (lcms2 not needed for preview extraction).
RUN wget -q --no-check-certificate https://www.dechifro.org/dcraw/dcraw.c && \
    gcc -o /usr/local/bin/dcraw -DNO_JASPER -DNO_LCMS dcraw.c -lm -ljpeg && \
    rm dcraw.c

FROM alpine:3.21

RUN apk add --no-cache ca-certificates ffmpeg libwebp-tools

WORKDIR /app

COPY --from=builder /app/photos .
COPY --from=builder /usr/local/bin/dcraw /usr/local/bin/dcraw

ENTRYPOINT ["/app/photos"]
CMD ["serve"]
