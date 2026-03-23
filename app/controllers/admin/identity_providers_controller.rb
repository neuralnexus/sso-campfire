class Admin::IdentityProvidersController < Admin::BaseController
  before_action :load_provider, only: %i[show edit update enable disable rotate_scim_token refresh_metadata test_configuration]

  def index
    @providers = IdentityProvider.order(:name)
  end

  def show
    @events = @provider.provisioning_events.recent.limit(50)
  end

  def new
    @provider = IdentityProvider.new(protocol: "oidc")
  end

  def create
    @provider = IdentityProvider.new(provider_params)

    if @provider.save
      redirect_to admin_identity_provider_path(@provider), notice: "Identity provider created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @provider.update(provider_params)
      redirect_to admin_identity_provider_path(@provider), notice: "Identity provider updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def enable
    @provider.update!(enabled: true)
    redirect_to admin_identity_provider_path(@provider), notice: "Provider enabled."
  end

  def disable
    @provider.update!(enabled: false)
    redirect_to admin_identity_provider_path(@provider), notice: "Provider disabled."
  end

  # Issues a new SCIM bearer token. The raw token is shown once and never again.
  def rotate_scim_token
    @provider.scim_tokens.active.each(&:revoke!)

    @scim_token, @raw_token = ScimToken.issue!(
      provider: @provider,
      name:     "Rotated #{Time.current.to_fs(:db)}"
    )

    ProvisioningEvent.record(
      provider:    @provider,
      event_type:  "token_rotate",
      user:        Current.user,
      success:     true,
      source_ip:   request.remote_ip,
      request_id:  request.request_id
    )

    render :rotate_scim_token
  end

  # Enqueues a background metadata refresh for this provider.
  # The job validates issuer consistency before writing any updates.
  def refresh_metadata
    Identity::RefreshMetadataJob.perform_later(@provider.id)
    redirect_to admin_identity_provider_path(@provider),
      notice: "Metadata refresh enqueued. Endpoints will update shortly."
  end

  # Validates provider configuration without enabling it.
  def test_configuration
    @provider.valid?
    @errors = @provider.errors.full_messages

    render :test_configuration
  end

  private

    def load_provider
      @provider = IdentityProvider.find(params[:id])
    end

    def provider_params
      params.require(:identity_provider).permit(
        :name, :protocol, :issuer, :discovery_url, :client_id,
        :encrypted_client_secret, :scopes,
        :claim_sub, :claim_email, :claim_email_verified, :claim_name, :claim_groups,
        :jit_provisioning, :scim_enabled, :require_pkce, :require_email_verified,
        :allow_email_linking, :soft_delete_on_scim_deactivate, :clock_skew_seconds
        # :enabled is set only via explicit enable/disable actions, not mass-assignment
      )
    end
end
