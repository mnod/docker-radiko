From alpine:3.14.2

RUN set -ex \
 && apk update \
 && apk upgrade --available \
 && apk add python3 git ffmpeg tzdata \
 && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && apk del tzdata \
 && rm -rf /var/cache/apk/*

RUN git clone https://gist.github.com/81a309e13e8f89b3e104563a967c6ff1.git radiko \
 && mv radiko/radiko.py /usr/local/bin/radiko.py \
 && chmod +x /usr/local/bin/radiko.py \
 && rm -rf radiko \
 && adduser -s /bin/sh -D docker

VOLUME ["/media/recorder"]
USER docker
ENTRYPOINT ["/usr/local/bin/radiko.py"]
