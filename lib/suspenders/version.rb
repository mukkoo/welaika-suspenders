module Suspenders
  RAILS_VERSION = "~> 5.2.1".freeze
  POSTGRES_VERSION = "10.4".freeze # Used in CI
  RUBY_VERSION = IO.
    read("#{File.dirname(__FILE__)}/../../.ruby-version").
    strip.
    freeze
  VERSION = "2.29.0".freeze
end
