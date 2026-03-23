class Admin::GroupMappingsController < Admin::BaseController
  before_action :load_provider
  before_action :load_mapping, only: %i[edit update destroy]

  def index
    @mappings = @provider.group_mappings.ordered
  end

  def new
    @mapping = @provider.group_mappings.build
  end

  def create
    @mapping = @provider.group_mappings.build(mapping_params)

    if @mapping.save
      redirect_to admin_identity_provider_group_mappings_path(@provider), notice: "Group mapping created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @mapping.update(mapping_params)
      redirect_to admin_identity_provider_group_mappings_path(@provider), notice: "Group mapping updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mapping.destroy!
    redirect_to admin_identity_provider_group_mappings_path(@provider), notice: "Group mapping removed."
  end

  private

    def load_provider
      @provider = IdentityProvider.find(params[:identity_provider_id])
    end

    def load_mapping
      @mapping = @provider.group_mappings.find(params[:id])
    end

    def mapping_params
      params.require(:group_mapping).permit(
        :external_group_id, :external_group_name, :role, :room_id, :enabled, :priority
      )
    end
end
