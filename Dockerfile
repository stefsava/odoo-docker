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

# Switch to root to install system dependencies
USER root

# Install additional system dependencies if required (from sources/apt.txt)
COPY sources/apt.txt /tmp/apt.txt
RUN apt-get update && xargs -a /tmp/apt.txt apt-get install -y --no-install-recommends \
    git python3-venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/apt.txt

# Create Odoo system user
# RUN adduser --system --home=/opt/odoo --group odoo
# The official Odoo image already includes the 'odoo' system user.
# Removed: timezone settings
# The official Odoo image sets the timezone to UTC by default.

# Clone Odoo source code
# RUN git clone --depth 1 --branch ${GIT_BRANCH} https://www.github.com/odoo/odoo /opt/odoo
# The official Odoo image includes the Odoo source code, so this step is unnecessary.
# Removed: locale generation
# The official Odoo image already has locale settings configured.

# Copy custom Odoo addons to the extra-addons directory
# Removed: manual Python compilation
# The official Odoo image includes a compatible Python version.

# Copy custom Odoo addons
COPY sources/addons /mnt/extra-addons
RUN chown -R odoo:odoo /mnt/extra-addons
# This allows for the inclusion of custom addons.

# Copy the custom Odoo configuration file
COPY sources/odoo.conf /etc/odoo/odoo.conf
RUN chown odoo:odoo /etc/odoo/odoo.conf
# This enables the use of a custom configuration file.

# Install Python dependencies (from requirements.txt)
COPY sources/requirements.txt /tmp/requirements.txt
# Create a virtual environment and install dependencies inside it
RUN python3 -m venv /opt/odoo/venv && \
    /opt/odoo/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt
# Using a virtual environment to avoid conflicts with system packages.

# Ensure Odoo uses the virtual environment
ENV PATH="/opt/odoo/venv/bin:$PATH"
# This ensures that Odoo uses the virtual environment for Python dependencies.

# Install wkhtmltopdf
# RUN apt-get update && apt-get install -y wkhtmltopdf
# The official Odoo image already includes wkhtmltopdf, so this step can be omitted.

# Install PostgreSQL client (optional, not required in Odoo container)
# RUN apt-get update && apt-get install -y postgresql-client
# The PostgreSQL client is already included in the official Odoo image,
# so installing it again is unnecessary.
# Removed: redundant `pip install`
# Dependencies are already installed inside the virtual environment.

# Copy the custom startup script
COPY sources/startup.sh /usr/local/bin/startup.sh
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
# Removed: PostgreSQL client installation
# The PostgreSQL client is already included in the official Odoo image.

# Use README for the help & man commands
ADD README.md /usr/share/man/man.txt

# Remove anchors and links to anchors to improve readability
RUN sed -i '/^<a name=/ d' /usr/share/man/man.txt
RUN sed -i -e 's/\[\^\]\[toc\]//g' /usr/share/man/man.txt
RUN sed -i -e 's/\(\[.*\]\)(#.*)/\1/g' /usr/share/man/man.txt

# For help command, only keep the "Usage" section
RUN from=$( awk '/^## Usage/{ print NR; exit }' /usr/share/man/man.txt ) && \
  from=$(expr $from + 1) && \
  to=$( awk '/^    \$ docker-compose up/{ print NR; exit }' /usr/share/man/man.txt ) && \
  head -n $to /usr/share/man/man.txt | \
  tail -n +$from | \
  tee /usr/share/man/help.txt > /dev/null

# Use dumb-init as init system to launch the boot script
ADD https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64.deb /opt/sources/dumb-init.deb
RUN dpkg -i /opt/sources/dumb-init.deb

# Add boot script
ADD bin/boot /usr/bin/boot

# Switch back to the Odoo user for security
USER odoo

# Set entrypoint
ENTRYPOINT [ "/usr/bin/dumb-init", "/usr/bin/boot" ]
CMD [ "help" ]

# Expose the Odoo ports (for linked containers)
EXPOSE 8069 8072
