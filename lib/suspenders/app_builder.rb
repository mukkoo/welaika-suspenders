require "forwardable"

module Suspenders
  class AppBuilder < Rails::AppBuilder
    include Suspenders::Actions
    extend Forwardable

    def_delegators :heroku_adapter,
                   :create_heroku_application_manifest_file,
                   :create_heroku_pipeline,
                   :create_production_heroku_app,
                   :create_staging_heroku_app,
                   :create_review_apps_setup_script,
                   :set_heroku_rails_secrets,
                   :set_heroku_backup_schedule,
                   :set_heroku_remotes,
                   :set_heroku_application_host

    def readme
      template 'README.md.erb', 'README.md'
    end

    def gitignore
      copy_file "suspenders_gitignore", ".gitignore"
    end

    def gemfile
      template "Gemfile.erb", "Gemfile"
    end

    def setup_rack_mini_profiler
      copy_file(
        "rack_mini_profiler.rb",
        "config/initializers/rack_mini_profiler.rb",
      )
    end

    def raise_on_missing_assets_in_test
      configure_environment "test", "config.assets.raise_runtime_errors = true"
    end

    def raise_on_delivery_errors
      replace_in_file 'config/environments/development.rb',
        'raise_delivery_errors = false', 'raise_delivery_errors = true'
    end

    def set_test_delivery_method
      inject_into_file(
        "config/environments/development.rb",
        "\n  config.action_mailer.delivery_method = :letter_opener",
        after: "config.action_mailer.raise_delivery_errors = true",
      )
    end

    def add_bullet_gem_configuration
      config = <<-RUBY
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
  end

      RUBY

      inject_into_file(
        "config/environments/development.rb",
        config,
        after: "config.action_mailer.raise_delivery_errors = true\n",
      )
    end

    def raise_on_unpermitted_parameters
      config = <<-RUBY
    config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      inject_into_class "config/application.rb", "Application", config
    end

    def configure_quiet_assets
      config = <<-RUBY
    config.assets.quiet = true
      RUBY

      inject_into_class "config/application.rb", "Application", config
    end

    def provide_setup_script
      template "bin_setup", "bin/setup", force: true
      run "chmod a+x bin/setup"
    end

    def provide_dev_prime_task
      copy_file 'dev.rake', 'lib/tasks/dev.rake'
    end

    def configure_generators
      config = <<-RUBY

    config.generators do |generate|
      generate.controller_specs false
      generate.helper false
      generate.javascripts false
      generate.request_specs false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
    end

      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def set_up_factory_girl_for_rspec
      copy_file 'factory_girl_rspec.rb', 'spec/support/factory_girl.rb'
    end

    def add_helpers_for_rspec
      copy_file 'queries_helper_rspec.rb', 'spec/support/queries_helper.rb'
      copy_file 'fixtures_helper_rspec.rb', 'spec/support/fixtures_helper.rb'
    end

    def set_up_faker
      copy_file 'faker_rspec.rb', 'spec/support/faker.rb'
    end

    def configure_smtp
      copy_file 'smtp.rb', 'config/smtp.rb'

      prepend_file 'config/environments/production.rb',
        %{require Rails.root.join("config/smtp")\n}

      config = <<-RUBY

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = SMTP_SETTINGS
      RUBY

      inject_into_file 'config/environments/production.rb', config,
        after: "config.action_mailer.raise_delivery_errors = false"
    end

    def enable_rack_canonical_host
      config = <<-RUBY

  if ENV.fetch("HEROKU_APP_NAME", "").include?("staging-pr-")
    ENV["APPLICATION_HOST"] = ENV["HEROKU_APP_NAME"] + ".herokuapp.com"
  end

  config.middleware.use Rack::CanonicalHost, ENV.fetch("APPLICATION_HOST")
      RUBY

      inject_into_file(
        "config/environments/production.rb",
        config,
        after: "Rails.application.configure do",
      )
    end

    def enable_rack_deflater
      configure_environment "production", "config.middleware.use Rack::Deflater"
    end

    def setup_asset_host
      replace_in_file 'config/environments/production.rb',
        "# config.action_controller.asset_host = 'http://assets.example.com'",
        'config.action_controller.asset_host = ENV.fetch("ASSET_HOST", ENV.fetch("APPLICATION_HOST"))'

      replace_in_file 'config/initializers/assets.rb',
        "config.assets.version = '1.0'",
        'config.assets.version = (ENV["ASSETS_VERSION"] || "1.0")'

      config = <<-EOD
config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=31557600",
  }
      EOD

      configure_environment("production", config)
    end

    def setup_secret_token
      template 'secrets.yml', 'config/secrets.yml', force: true
    end

    def disallow_wrapping_parameters
      remove_file "config/initializers/wrap_parameters.rb"
    end

    def create_partials_directory
      empty_directory 'app/views/application'
    end

    def create_shared_flashes
      copy_file '_flashes.html.slim', 'app/views/application/_flashes.html.slim'
      copy_file "flashes_helper.rb", "app/helpers/flashes_helper.rb"
    end

    def create_shared_javascripts
      copy_file '_javascript.html.slim', 'app/views/application/_javascript.html.slim'
    end

    def create_shared_css_overrides
      copy_file(
        "_css_overrides.html.erb",
        "app/views/application/_css_overrides.html.erb",
      )
    end

    def create_application_layout
      remove_file 'app/views/layouts/application.html.erb'
      template 'suspenders_layout.html.slim',
        'app/views/layouts/application.html.slim',
        force: true
    end

    def use_postgres_config_template
      template 'postgresql_database.yml.erb', 'config/database.yml',
        force: true
    end

    def create_database
      bundle_command 'exec rake db:create db:migrate'
    end

    def replace_gemfile(path)
      template 'Gemfile.erb', 'Gemfile', force: true do |content|
        if path
          content.gsub(%r{gem .suspenders.}) { |s| %{#{s}, path: "#{path}"} }
        else
          content
        end
      end
    end

    def set_ruby_to_version_being_used
      create_file '.ruby-version', "#{Suspenders::RUBY_VERSION}\n"
    end

    def enable_database_cleaner
      copy_file 'database_cleaner_rspec.rb', 'spec/support/database_cleaner.rb'
    end

    def provide_shoulda_matchers_config
      copy_file(
        "shoulda_matchers_config_rspec.rb",
        "spec/support/shoulda_matchers.rb"
      )
    end

    def configure_spec_support_features
      empty_directory_with_keep_file 'spec/features'
      empty_directory_with_keep_file 'spec/support/features'
    end

    def configure_rspec
      remove_file "spec/rails_helper.rb"
      remove_file "spec/spec_helper.rb"
      copy_file "rails_helper.rb", "spec/rails_helper.rb"
      copy_file "spec_helper.rb", "spec/spec_helper.rb"
    end

    def configure_ci
      template "circle.yml.erb", "circle.yml"
    end

    def configure_i18n_for_test_environment
      copy_file "i18n.rb", "spec/support/i18n.rb"
    end

    def configure_i18n_for_missing_translations
      raise_on_missing_translations_in("development")
      raise_on_missing_translations_in("test")
    end

    def configure_action_mailer_in_specs
      copy_file 'action_mailer.rb', 'spec/support/action_mailer.rb'
    end

    def configure_capybara_webkit
      copy_file "capybara_webkit.rb", "spec/support/capybara_webkit.rb"
    end

    def configure_locales_and_time_zone
      remove_file "config/locales/en.yml"
      template "config_locales_it.yml.erb", "config/locales/it.yml"

      config = <<-RUBY
    config.i18n.available_locales = [:en, :it]
    config.i18n.default_locale = :it
    config.time_zone = 'Rome'
      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def configure_rack_timeout
      rack_timeout_config = <<-RUBY
Rack::Timeout.timeout = (ENV["RACK_TIMEOUT"] || 10).to_i
      RUBY

      append_file "config/environments/production.rb", rack_timeout_config
    end

    def configure_slim
      copy_file 'slim.rb', 'config/initializers/slim.rb'
    end

    def configure_simple_form
      bundle_command "exec rails generate simple_form:install"
    end

    def configure_draper
      bundle_command "exec rails generate draper:install"
    end

    def configure_active_interaction
      copy_file "sample_service.rb", "app/services/sample_service.rb"
    end

    def configure_action_mailer
      action_mailer_host "development", %{"localhost:3000"}
      action_mailer_host "test", %{"www.example.com"}
      action_mailer_host "production", %{ENV.fetch("APPLICATION_HOST")}
    end

    def generate_rspec
      generate 'rspec:install'
    end

    def replace_default_puma_configuration
      copy_file "puma.rb", "config/puma.rb", force: true
    end

    def set_up_forego
      copy_file "Procfile", "Procfile"
    end

    def setup_default_directories
      [
        'app/decorators',
        'app/forms',
        'app/queries',
        'app/services',
        'app/views/pages',
        'spec/decorators',
        'spec/fixtures',
        'spec/forms',
        'spec/helpers',
        'spec/lib',
        'spec/queries',
        'spec/requests',
        'spec/services',
        'spec/support/matchers',
        'spec/support/mixins',
        'spec/support/shared_examples'
      ].each do |dir|
        empty_directory_with_keep_file dir
      end
    end

    def copy_dotfiles
      directory("dotfiles", ".")
    end

    def init_git
      run 'git init'
    end

    def create_heroku_apps(flags)
      create_staging_heroku_app(flags)
      create_production_heroku_app(flags)
    end

    def create_deploy_script
      copy_file "bin_deploy", "bin/deploy"

      instructions = <<-MARKDOWN

## Deploying

If you have previously run the `./bin/setup` script,
you can deploy to staging and production with:

    % ./bin/deploy staging
    % ./bin/deploy production
      MARKDOWN

      append_file "README.md", instructions
      run "chmod a+x bin/deploy"
    end

    def setup_brakeman
      copy_file "brakeman.rake", "lib/tasks/brakeman.rake"
    end

    def setup_slim_lint
      copy_file "slim-lint.rake", "lib/tasks/slim-lint.rake"
      copy_file "slim-lint.yml", ".slim-lint.yml"
    end

    def setup_rubocop
      copy_file "rubocop.rake", "lib/tasks/rubocop.rake"
      copy_file "rubocop.yml", ".rubocop.yml"
      copy_file "rubocop_todo.yml", ".rubocop_todo.yml"
    end

    def setup_bundler_audit
      copy_file "bundler_audit.rake", "lib/tasks/bundler_audit.rake"
    end

    def setup_spring
      bundle_command "exec spring binstub --all"
    end

    def create_binstubs
      bundle_command "binstubs brakeman"
      bundle_command "binstubs rubocop"
      bundle_command "binstubs slim_lint"
    end

    def copy_miscellaneous_files
      copy_file "browserslist", "browserslist"
      copy_file "errors.rb", "config/initializers/errors.rb"
      copy_file "json_encoding.rb", "config/initializers/json_encoding.rb"
    end

    def customize_error_pages
      meta_tags =<<-EOS
  <meta charset="utf-8" />
  <meta name="ROBOTS" content="NOODP" />
  <meta name="viewport" content="initial-scale=1" />
      EOS

      %w(500 404 422).each do |page|
        inject_into_file "public/#{page}.html", meta_tags, after: "<head>\n"
        replace_in_file "public/#{page}.html", /<!--.+-->\n/, ''
      end
    end

    def remove_config_comment_lines
      config_files = [
        "application.rb",
        "environment.rb",
        "environments/development.rb",
        "environments/production.rb",
        "environments/test.rb",
      ]

      config_files.each do |config_file|
        path = File.join(destination_root, "config/#{config_file}")

        accepted_content = File.readlines(path).reject do |line|
          line =~ /^.*#.*$/ || line =~ /^$\n/
        end

        File.open(path, "w") do |file|
          accepted_content.each { |line| file.puts line }
        end
      end
    end

    def remove_routes_comment_lines
      replace_in_file 'config/routes.rb',
        /Rails\.application\.routes\.draw do.*end/m,
        "Rails.application.routes.draw do\nend"
    end

    def setup_default_rake_task
      append_file 'Rakefile' do
        <<-EOS
task(:default).clear

if defined? RSpec
  task(:spec).clear
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.verbose = false
  end
end

task default: :rubocop
task default: :slim_lint
task default: 'brakeman:check'
task default: 'bundle:audit'
task default: :spec
        EOS
      end
    end

    private

    def raise_on_missing_translations_in(environment)
      config = 'config.action_view.raise_on_missing_translations = true'

      uncomment_lines("config/environments/#{environment}.rb", config)
    end

    def heroku_adapter
      @heroku_adapter ||= Adapters::Heroku.new(self)
    end
  end
end
