# Use the official Odoo 18 image as the base
FROM odoo:18.0

# Maintainer information
LABEL maintainer="Stefano Savanelli <stefano@savanelli.it> (Inspired by Elico Corp <webmaster@elico-corp.com>)"

# Define build constants
# ENV GIT_BRANCH=17.0 \
#     PYTHON_BIN=python3 \
#     SERVICE_BIN=odoo-bin
# These environment variables are not necessary when using the official Odoo image,
# as it already sets up the appropriate environment.

# Set timezone to UTC
# RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
# The official Odoo image sets the timezone to UTC by default, so this step is redundant.

# Generate locales
# RUN apt update \
#     && apt -yq install locales \
#     && locale-gen en_US.UTF-8 \
#     && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
# Locale settings are already configured in the official Odoo image.

# Install Python 3.10.11
# RUN apt-get -yq install wget libffi-dev
# RUN mkdir /python && cd /python && \
#     wget -c https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz
# RUN cd /python && tar -zxvf Python-3.10.11.tgz && \
#     cd Python-3.10.11 && \
#     ls -lhR && \
#     ./configure --enable-optimizations && \
#     make install && \
#     rm -rf /python
# The official Odoo image already includes a compatible Python version,
# so recompiling Python is unnecessary.

# Install additional system dependencies if required (from apt.txt)
COPY apt.txt /tmp/apt.txt
RUN apt-get update && xargs -a /tmp/apt.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/apt.txt
# This section allows for the installation of additional APT packages as needed.

# Create Odoo system user
# RUN adduser --system --home=/opt/odoo --group odoo
# The official Odoo image already includes the 'odoo' system user.

# Clone Odoo source code
# RUN git clone --depth 1 --branch ${GIT_BRANCH} https://www.github.com/odoo/odoo /opt/odoo
# The official Odoo image includes the Odoo source code, so this step is unnecessary.

# Copy custom Odoo addons to the extra-addons directory
COPY ./addons /mnt/extra-addons
RUN chown -R odoo:odoo /mnt/extra-addons
# This allows for the inclusion of custom addons.

# Copy the custom Odoo configuration file
COPY ./odoo.conf /etc/odoo/
RUN chown odoo:odoo /etc/odoo/odoo.conf
# This enables the use of a custom configuration file.

# Install Python dependencies (from requirements.txt)
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && rm -f /tmp/requirements.txt
# This installs additional Python packages as specified.

# Install wkhtmltopdf
# RUN apt-get update && apt-get install -y wkhtmltopdf
# The official Odoo image already includes wkhtmltopdf, so this step can be omitted.

# Install PostgreSQL client (optional, not required in Odoo container)
# RUN apt-get update && apt-get install -y postgresql-client
# The PostgreSQL client is already included in the official Odoo image,
# so installing it again is unnecessary.

# Copy the custom startup script
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh
# This allows for custom startup procedures.

# Ensure volume directories are properly set up
RUN mkdir -p /var/lib/odoo /mnt/extra-addons && \
    chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons
# VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]
# These directories are already defined as volumes in the official Odoo image,
# so redefining them is unnecessary.

# Expose required ports for Odoo services (optional, already handled by the official image)
# EXPOSE 8069 8072
# The official Odoo image already exposes these ports by default.
# Additionally, in a Dokku environment, port mapping is handled by the reverse proxy.


# Use the official entrypoint script and specify the custom startup command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/bin/startup.sh"]
# This uses the default entrypoint and specifies a custom command to run at startup.
