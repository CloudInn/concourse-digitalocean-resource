FROM alpine

RUN apk -U add bash curl jq pcre-tools openssh-client

# Copy assets
COPY assets/ /opt/resource/
