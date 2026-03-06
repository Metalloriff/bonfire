FROM ubuntu:24.04

LABEL maintainer="Metalloriff"
LABEL description="Bonfire server with ntfy.sh"

ARG RELEASES_URL="https://api.github.com/repos/metalloriff/bonfire/releases"
ARG ZIP_NAME="bonfire-linux.zip"
ARG EXECUTABLE="bonfire.x86_64"

RUN apt-get update -qq && \
	apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	unzip \
	libatomic1 && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -s ${RELEASES_URL} \
	| grep "browser_download_url.*${ZIP_NAME}" \
	| cut -d '"' -f 4 \
	| head -n 1 \
	| xargs -n 1 curl -L -o build.zip && \
	unzip -q build.zip -d release && \
	chmod +x release/${EXECUTABLE} && \
	rm build.zip

EXPOSE 26969/udp
EXPOSE 26969/tcp

ENTRYPOINT [ "/app/release/bonfire.x86_64" ]
CMD [ "--headless", "--server", "--docker" ]
