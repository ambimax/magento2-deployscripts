FROM ambimax/php7.4-cli-buster AS downloader
SHELL ["/bin/bash", "-c"]

ARG VERSION=2.4.2
ARG DOWNLOAD_URL=https://github.com/magento/magento2/archive/${VERSION}.tar.gz

RUN curl --compressed --location --silent --show-error ${DOWNLOAD_URL} | tar -xz  -C /opt/; \
  rm -rf /var/www; \
  mv /opt/magento2-${VERSION} /var/www; \
  cd /var/www; \
  composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-dev \
    --optimize-autoloader \
    --no-progress \
    --no-suggest \
    --apcu-autoloader; \
  mkdir -p /var/www/{var,generated,app/etc,pub/{media,static}}; \
  chmod 777 -R /var/www/{var,generated,app/etc,pub/{media,static}};

WORKDIR /var/www/
