require "test_helper"

class Auth::OidcControllerTest < ActionDispatch::IntegrationTest
  test "start is inert in local_only mode" do
    with_identity_mode("local_only") do
      get start_auth_oidc_url
    end

    assert_redirected_to new_session_url
  end

  test "callback is inert in local_only mode" do
    with_identity_mode("local_only") do
      get callback_auth_oidc_url, params: { state: "x", code: "y" }
    end

    assert_redirected_to failure_auth_oidc_url(error: "no_provider_configured")
  end

  private

    def with_identity_mode(mode)
      previous_mode = Rails.application.config.x.identity.mode
      Rails.application.config.x.identity.mode = mode
      yield
    ensure
      Rails.application.config.x.identity.mode = previous_mode
    end
end
