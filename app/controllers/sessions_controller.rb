class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_rejection :too_many_requests }

  before_action :ensure_user_exists, only: :new
  before_action :enforce_oidc_required, only: %i[new create]

  def new
  end

  def create
    user = User.active.find_by(email_address: params[:email_address].to_s.downcase.strip)

    # In oidc_required mode, deny password login for all non-break-glass users
    # before password verification to avoid credential oracles.
    if identity_mode_oidc_required? && !user&.break_glass_admin?
      render_rejection :forbidden
      return
    end

    if user&.authenticate(params[:password])
      start_new_session_for user
      redirect_to post_authenticating_url
    else
      render_rejection :unauthorized
    end
  end

  def destroy
    remove_push_subscription
    terminate_current_session
    redirect_to root_url
  end

  private
    def ensure_user_exists
      redirect_to first_run_url if User.none?
    end

    def enforce_oidc_required
      # In oidc_required mode, redirect non-admin users to OIDC start.
      # The login form remains accessible so break-glass admins can still
      # authenticate with a password.
      if identity_mode_oidc_required?
        flash.now[:notice] = "Enterprise login is required. Use the SSO button or log in as administrator."
      end
    end

    def render_rejection(status)
      flash.now[:alert] = "Too many requests or unauthorized."
      render :new, status: status
    end

    def remove_push_subscription
      if endpoint = params[:push_subscription_endpoint]
        Push::Subscription.destroy_by(endpoint: endpoint, user_id: Current.user.id)
      end
    end
end
