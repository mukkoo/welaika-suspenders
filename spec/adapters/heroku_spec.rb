require "spec_helper"

module Suspenders
  module Adapters
    RSpec.describe Heroku do
      it "sets the heroku remotes" do
        setup_file = "bin/setup"
        app_builder = double(app_name: app_name)
        allow(app_builder).to receive(:append_file)

        Heroku.new(app_builder).set_heroku_remotes

        expect(app_builder).to have_received(:append_file).
          with(setup_file, /git remote add -f production git@heroku\.com:#{app_name.dasherize}-production\.git/)
        expect(app_builder).to have_received(:append_file).
          with(setup_file, /git remote add -f staging git@heroku\.com:#{app_name.dasherize}-staging\.git/)
      end

      it "sets the heroku rails secrets" do
        app_builder = double(app_name: app_name)
        allow(app_builder).to receive(:run)

        Heroku.new(app_builder).set_heroku_rails_secrets

        expect(app_builder).to(
          have_configured_var("staging", "SECRET_KEY_BASE"),
        )
        expect(app_builder).to(
          have_configured_var("production", "SECRET_KEY_BASE"),
        )
      end

      it "sets the heroku backup schedule" do
        app_builder = double(app_name: app_name)
        allow(app_builder).to receive(:run)

        Heroku.new(app_builder).set_heroku_backup_schedule

        expect(app_builder).to have_backup_schedule("staging")
        expect(app_builder).to have_backup_schedule("production")
      end

      it "sets the application host" do
        app_builder = double(app_name: app_name)
        allow(app_builder).to receive(:run)

        Heroku.new(app_builder).set_heroku_application_host

        expect(app_builder).to(
          have_configured_var("staging", "APPLICATION_HOST"),
        )

        expect(app_builder).to(
          have_configured_var("production", "APPLICATION_HOST"),
        )
      end

      def app_name
        SuspendersTestHelpers::APP_NAME
      end

      def have_backup_schedule(remote_name)
        have_received(:run).
          with(/pg:backups:schedule DATABASE_URL --at '10:00 UTC' --remote #{remote_name}/)
      end

      def have_configured_var(remote_name, var)
        have_received(:run).with(/config:add #{var}=.+ --remote #{remote_name}/)
      end
    end
  end
end
