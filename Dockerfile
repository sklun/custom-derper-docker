FROM golang:latest AS builder
WORKDIR /app
ENV CGO_ENABLED=0
RUN go install tailscale.com/cmd/derper@latest

FROM alpine
WORKDIR /app

ENV TZ Asia/Shanghai
ENV DERP_DOMAIN domain/ip
ENV DERP_ADDR :443
ENV DERP_HTTP_PORT 80
ENV DERP_CERT_MODE manual
ENV DERP_CERT_DIR /app/certs
ENV DERP_STUN true
ENV DERP_STUN_PORT 3478
ENV DERP_VERIFY_CLIENTS true
ENV DERP_VERIFY_CLIENT_URL ""

COPY --from=builder /go/bin/derper .

RUN apk add tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone && apk del tzdata \
    && apk add ca-certificates \
    && mkdir /app/certs

CMD /app/derper \
    --hostname=$DERP_DOMAIN \
    --a=$DERP_ADDR \
    --http-port=$DERP_HTTP_PORT \
    --certmode=$DERP_CERT_MODE \
    --certdir=$DERP_CERT_DIR \
    --stun=$DERP_STUN  \
    --stun-port=$DERP_STUN_PORT \
    --verify-clients=$DERP_VERIFY_CLIENTS \
    --verify-client-url=$DERP_VERIFY_CLIENT_URL
