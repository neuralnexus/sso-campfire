ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

require "rails/test_help"
require "minitest/unit"
require "mocha/minitest"
require "webmock/minitest"
require "turbo/broadcastable/test_helper"

WebMock.enable!

encryption = Rails.application.config.active_record.encryption
if encryption.primary_key.blank? || encryption.deterministic_key.blank? || encryption.key_derivation_salt.blank?
  base = Rails.application.secret_key_base
  primary = Digest::SHA256.hexdigest("test-arenc-primary-#{base}")
  deterministic = Digest::SHA256.hexdigest("test-arenc-deterministic-#{base}")
  salt = Digest::SHA256.hexdigest("test-arenc-salt-#{base}")

  encryption.primary_key = [ primary ]
  encryption.deterministic_key = [ deterministic ]
  encryption.key_derivation_salt = salt

  ActiveRecord::Encryption.config.primary_key = [ primary ]
  ActiveRecord::Encryption.config.deterministic_key = [ deterministic ]
  ActiveRecord::Encryption.config.key_derivation_salt = salt
end

class ActiveSupport::TestCase
  include ActiveJob::TestHelper

  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  include SessionTestHelper, MentionTestHelper, TurboTestHelper

  setup do
    ActionCable.server.pubsub.clear

    Rails.configuration.tap do |config|
      config.x.web_push_pool.shutdown
      config.x.web_push_pool = WebPush::Pool.new \
        invalid_subscription_handler: config.x.web_push_pool.invalid_subscription_handler
    end

    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.reset!
  end
end
