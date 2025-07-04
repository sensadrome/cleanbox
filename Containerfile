# Containerfile

FROM ubi/ruby-26-bundler-2.2.9

WORKDIR /opt/app-root/src

# Copy Gemfile first for cache efficiency
COPY Gemfile Gemfile.lock ./

# Configure bundler to install gems locally (avoiding permission issues)
RUN bundle config set --local path vendor/bundle && \
    bundle install

# Now copy the rest of the app
COPY . .

# No default CMD — pass at runtime
