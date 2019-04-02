FROM ruby:2.5.5-slim

LABEL maintainer="info@appvia.io"
LABEL source="https://github.com/appvia/appvia-hub"

ENV RAILS_ENV production
ENV NODE_ENV production

RUN apt-get update && apt-get upgrade -u -y && apt-get install -qq -y \
    bash curl gnupg2 build-essential \
    --fix-missing --no-install-recommends

RUN echo "deb [arch=amd64] http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

RUN curl -sL https://deb.nodesource.com/setup_11.x | bash -
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update && apt-get install -qq -y \
    nodejs yarn libpq-dev \
    --fix-missing --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

ENV APP_PATH /app
WORKDIR $APP_PATH

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 20 --retry 5 --deployment --without development test

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --no-cache --production && yarn cache clean

COPY . .
RUN SECRET_KEY_BASE=foo SECRET_SALT=bar DATABASE_URL=postgresql://user:pass@127.0.0.1/dbname bin/rails assets:precompile \
    && rm -rf node_modules/

RUN adduser --system --group --uid 1000 app \
    && chown -R app:app $APP_PATH

ENV HOME $APP_PATH
USER 1000

ENV PORT 3001

ENTRYPOINT ["bin/rails"]
CMD ["server"]
