ARG RUBY_VERSION=3.2.5

#use ruby base image
FROM ruby:$RUBY_VERSION-slim AS base

# set work dir
WORKDIR /code

# install dependencies
RUN apt-get update && apt-get install build-essential curl file git gnupg2 imagemagick libpq-dev nodejs npm -y && apt-get clean

# yarn manages the front-end JS/CSS packages that replaced the rails-assets.org gems
RUN npm install --global yarn@1.22.22

# install supercronic - a cron alternative
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.12/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=048b95b48b708983effb2e5c935a1ef8483d9e3e

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

ENTRYPOINT ["docker/entrypoint.sh"]

EXPOSE 3000


FROM base AS development

# copy package manifests
COPY package.json yarn.lock ./

# install js dependencies; docker-compose mounts node_modules as a named volume,
# which docker seeds from this layer the first time it is created
RUN yarn install --frozen-lockfile --non-interactive

CMD bundle exec rails server -b 0.0.0.0


FROM base AS production

# copy gemfile
COPY Gemfile Gemfile.lock ./

# install gems
RUN bundle check || bundle install

# copy package manifests
COPY package.json yarn.lock ./

# install js dependencies
RUN yarn install --frozen-lockfile --non-interactive

# copy code
COPY . .

# precompile assets
RUN bundle exec rake assets:precompile

# run rails server, need bind for docker
CMD bundle exec whenever > /code/tess.crontab \
    && (supercronic /code/tess.crontab &) \
    && bundle exec rails server -b 0.0.0.0
