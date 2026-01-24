FROM ruby:3.4.5-alpine

RUN apk add --no-cache \
    build-base \
    tzdata

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

COPY . .

EXPOSE 3000

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
