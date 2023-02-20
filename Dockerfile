FROM ubuntu:20.04

# Instalando dependências iniciais
ARG DEBIAN_FRONTEND="noninteractive"

RUN apt-get update \
    && apt dist-upgrade; \
    apt-get install -y \
    wget \
    curl \
    p7zip-full \
    ca-certificates \
    qpdf \
    ghostscript


RUN mkdir -p /qualys
COPY qualysWAS.sh /
RUN chmod +x /qualysWAS.sh
ENTRYPOINT ["/qualysapi.sh"]