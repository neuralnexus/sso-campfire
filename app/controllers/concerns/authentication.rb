module Authentication
  extend ActiveSupport::Concern
  include SessionLookup

  included do
    before_action :require_authentication
    before_action :deny_bots
    before_action :enforce_active_account
    helper_method :signed_in?

    protect_from_forgery with: :exception, unless: -> { authenticated_by.bot_key? }
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :enforce_active_account, **options
    end

    def allow_bot_access(**options)
      skip_before_action :deny_bots, **options
    end

    def require_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :enforce_active_account, **options
      before_action :restore_authentication, :redirect_signed_in_user_to_root, **options
    end
  end

  private
    def signed_in?
      Current.user.present?
    end

    def require_authentication
      restore_authentication || bot_authentication || request_authentication
    end

    def restore_authentication
      if session = find_session_by_cookie
        resume_session session
      end
    end

    def bot_authentication
      if params[:bot_key].present? && bot = User.authenticate_bot(params[:bot_key].strip)
        Current.user = bot
        set_authenticated_by(:bot_key)
      end
    end

    def request_authentication
      # In oidc_required mode, send non-OIDC users directly to the OIDC start
      # endpoint rather than the password login form.
      if identity_mode_oidc_required?
        session[:return_to_after_authenticating] = request.url
        redirect_to start_auth_oidc_path
      else
        session[:return_to_after_authenticating] = request.url
        redirect_to new_session_url
      end
    end

    def redirect_signed_in_user_to_root
      redirect_to root_url if signed_in?
    end

    # Blocks deprovisioned or deactivated users from resuming sessions.
    # Break-glass admins are always permitted through.
    def enforce_active_account
      return unless signed_in?
      return if Current.user.break_glass_admin?

      unless Current.user.active?
        terminate_current_session
        redirect_to new_session_url, alert: "Your account has been deactivated."
      end
    end

    def start_new_session_for(user)
      user.sessions.start!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        authenticated_as session
      end
    end

    def resume_session(session)
      session.resume user_agent: request.user_agent, ip_address: request.remote_ip
      authenticated_as session
    end

    def terminate_current_session
      Current.session&.destroy!
      reset_session
      remove_authentication_cookie
    end

    def authenticated_as(session)
      Current.session = session
      set_authenticated_by(:session)
      set_authentication_cookie(session)
    end

    def post_authenticating_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def set_authentication_cookie(session)
      cookies.signed.permanent[:session_token] = { value: session.token, httponly: true, same_site: :lax }
    end

    def remove_authentication_cookie
      cookies.delete(:session_token)
    end

    def deny_bots
      head :forbidden if authenticated_by.bot_key?
    end

    def set_authenticated_by(method)
      @authenticated_by = method.to_s.inquiry
    end

    def authenticated_by
      @authenticated_by ||= "".inquiry
    end

    # Identity mode controls which login paths are available.
    # Modes: "local_only" | "local_plus_oidc" | "oidc_required"
    # Configured via Rails.application.config.x.identity.mode
    def identity_mode
      Rails.application.config.x.identity.mode.to_s
    end

    def identity_mode_oidc_required?
      identity_mode == "oidc_required" && IdentityProvider.active_oidc.present?
    end
end
