%w[
  .env
  .env.local
  .env.test
  .ruby-version
  .rbenv-vars
  tmp/restart.txt
  tmp/caching-dev.txt
  app/services/providers_registry.rb
].each { |path| Spring.watch(path) }
