# Stage 1: Build stage
FROM php:8.2-apache-bookworm AS builder

RUN apt-get update && apt update && apt upgrade -y
RUN apt-get install -y --no-install-recommends \
    wget \
    autoconf \
    ca-certificates \
    g++ \
    libtool \
    make \
    pkg-config \
    libmariadb-dev \
    libcurl4-openssl-dev \
    libfcgi-dev \
    python-is-python3 \ 
    python3-setuptools \
    python3-build \
    python3.11-venv \
    python3-pip \
    git \
    automake
    
RUN apt-get install -y --no-install-recommends \
    zlib1g-dev libpng-dev libjpeg-dev libfreetype-dev libxml2-dev

# Copy your source code
WORKDIR /app
COPY . .

# Build your application
ARG MYSQL_CONFIG=mariadb_config
RUN mkdir /boinc && ./_autosetup && ./configure --disable-client --disable-manager --prefix=/boinc
RUN make && make install
RUN bash ./package_step.sh /app /boinc

# configure php for boinc
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd mysqli pdo pdo_mysql xml


# Stage 2: Runtime stage
FROM php:8.2-apache-bookworm

# Active CGI pour .cgi scripts
RUN a2enmod cgi

RUN apt-get update
RUN apt-get install -y \
    python3 \
    python3-mysqldb \
    python-is-python3 \
    tini
    
ENV BOINC_PROJECT_DIR="/boinc_project_root/"
ENV PYTHONPATH="/boinc/share/boinc-server-maker/py"

# Copy files from builder
WORKDIR /boinc
COPY --from=builder /boinc .
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY ./container_entry.sh .

RUN echo "TOP_BUILD_DIR='/boinc/libexec/boinc-server-maker/'" > /boinc/share/boinc-server-maker/py/boinc_path_config.py

# Enable PHP extension from builder
RUN docker-php-ext-enable mysqli

# Add a symbolic link to serve boinc project website
RUN ln -s /boinc_project_root/project_website.httpd.conf /etc/apache2/sites-enabled/project_website.httpd.conf
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
 && sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf

# Add a non-root BOINC user for operation
RUN adduser --disabled-login --no-create-home --uid 1001 boincadm && usermod -a -G boincadm www-data
USER boincadm
ENV USER=boincadm

EXPOSE 8080
ENTRYPOINT ["/boinc/container_entry.sh"]
CMD ["serve"]
