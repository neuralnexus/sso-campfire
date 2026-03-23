class Auth::OidcController < ApplicationController
  allow_unauthenticated_access only: %i[start callback failure]

  # POST callback uses its own CSRF protection (state param validated in service).
  # GET callback is used by some IdPs; both are handled.
  protect_from_forgery except: %i[callback]

  before_action :load_provider

  def start
    unless oidc_login_enabled?
      redirect_to new_session_path, alert: "Enterprise login is currently disabled."
      return
    end

    result = Identity::OidcStart.new(
      session:  session,
      provider: @provider,
      request:  request
    ).call

    redirect_to result.authorization_uri, allow_other_host: true
  rescue Identity::Errors::NoProviderConfigured
    redirect_to root_path, alert: "Enterprise login is not configured."
  end

  def callback
    unless oidc_login_enabled?
      redirect_to failure_auth_oidc_path(error: "no_provider_configured")
      return
    end

    result = Identity::OidcCallback.new(
      params:   params,
      session:  session,
      provider: @provider,
      request:  request
    ).call

    # Rotate session after successful authentication to prevent session fixation.
    reset_session
    start_new_session_for result.user
    session[:oidc_provider_id] = result.provider.id

    redirect_to post_authenticating_url
  rescue Identity::Errors::AccountDeprovisioned
    redirect_to failure_auth_oidc_path(error: "account_deprovisioned")
  rescue Identity::Errors::RelinkDenied
    redirect_to failure_auth_oidc_path(error: "relink_denied")
  rescue Identity::Errors::EmailNotVerified
    redirect_to failure_auth_oidc_path(error: "email_not_verified")
  rescue Identity::Errors::Base => e
    Rails.logger.warn("[OIDC] Callback error: #{e.class} — #{e.message}")
    redirect_to failure_auth_oidc_path(error: e.class.name.demodulize.underscore)
  end

  def logout
    unless oidc_login_enabled?
      redirect_to root_path
      return
    end

    result = Identity::SessionLogout.new(
      user:    Current.user,
      session: session
    ).call

    reset_session

    if result.end_session_uri.present?
      redirect_to result.end_session_uri, allow_other_host: true
    else
      redirect_to root_path
    end
  end

  def failure
    @error = params[:error].to_s
  end

  private

    def load_provider
      if action_name == "callback"
        provider_id = session[:oidc_provider]
        @provider = IdentityProvider.enabled.find_by(id: provider_id) if provider_id.present?
      else
        @provider = IdentityProvider.active_oidc
      end
    end

    def oidc_login_enabled?
      %w[local_plus_oidc oidc_required].include?(Rails.application.config.x.identity.mode.to_s)
    end
end
