require "rails/generators"

module Suspenders
  class JsDriverGenerator < Rails::Generators::Base
    source_root File.expand_path(
      File.join("..", "..", "..", "templates"),
      File.dirname(__FILE__),
    )

    def add_gems
      gem 'capybara', '>= 2.15', '< 4.0', group: :test
      gem 'selenium-webdriver', group: :test
      Bundler.with_clean_env { run "bundle install" }
    end

    def configure_chromedriver
      copy_file "chromedriver.rb", "spec/support/chromedriver.rb"
    end
  end
end
