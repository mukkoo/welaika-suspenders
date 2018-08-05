# frozen_string_literal: true

if Rails.env.development? || Rails.env.test?
  require 'bundler/audit/task'
  Bundler::Audit::Task.new
end
