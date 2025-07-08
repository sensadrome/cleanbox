# Containerfile

FROM registry.redhat.io/ubi8/ruby-27

WORKDIR /opt/app-root/src

# Copy Gemfile first for cache efficiency
COPY Gemfile Gemfile.lock ./

# Configure bundler to install gems locally (avoiding permission issues)
RUN bundle config set --local path vendor/bundle && \
    bundle install

# Now copy the rest of the app
COPY --chown=1000:1000 . .
# No default CMD — pass at runtime
