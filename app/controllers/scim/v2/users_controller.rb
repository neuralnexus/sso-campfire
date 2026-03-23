class Scim::V2::UsersController < Scim::V2::BaseController
  def index
    render json: Scim::Users::Index.new(
      provider: current_provider,
      params:   params,
      base_url: base_url
    ).call
  end

  def show
    render json: Scim::Users::Show.new(
      provider: current_provider,
      id:       params[:id],
      base_url: base_url
    ).call
  end

  def create
    result = Scim::Users::Create.new(
      provider: current_provider,
      payload:  scim_payload,
      request:  request,
      base_url: base_url
    ).call

    render json: result, status: :created
  end

  def patch
    render json: Scim::Users::Patch.new(
      provider: current_provider,
      id:       params[:id],
      payload:  scim_payload,
      request:  request,
      base_url: base_url
    ).call
  end

  def replace
    render json: Scim::Users::Replace.new(
      provider: current_provider,
      id:       params[:id],
      payload:  scim_payload,
      request:  request,
      base_url: base_url
    ).call
  end

  # DELETE soft-deactivates the user and revokes sessions.
  # Hard deletion is never performed via SCIM — message history is preserved.
  def destroy
    Scim::Users::Destroy.new(
      provider: current_provider,
      id:       params[:id],
      request:  request
    ).call

    head :no_content
  end
end
