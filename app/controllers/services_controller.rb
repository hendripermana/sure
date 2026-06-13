class ServicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: %i[edit update destroy]

  layout :determine_layout

  def index
    respond_to do |format|
      format.html do
        @services = ServiceMerchant.available_to(Current.family)
      end
      format.turbo_stream do
        # Combobox search endpoint - return services matching search query with pagination
        per_page = 50
        page = (params[:page] || 1).to_i

        base_query = ServiceMerchant.available_to(Current.family).search(params[:q])

        total_count = base_query.count
        @services = base_query.offset((page - 1) * per_page).limit(per_page)

        # Calculate if there's a next page
        @next_page = (page * per_page < total_count) ? page + 1 : nil
      end
    end
  end

  def new
    @service = ServiceMerchant.new(family: Current.family)
    @categories = ServiceMerchant::CATEGORIES
  end

  def create
    @service = ServiceMerchant.new(service_params.merge(family: Current.family))

    respond_to do |format|
      if @service.save
        flash[:notice] = "Service created successfully!"
        return_to = params[:return_to]
        format.html { redirect_to return_to || services_path, notice: "Service created successfully!" }
        format.turbo_stream do
          if return_to.present?
            # When inside a modal, turbo frame navigation expects turbo_stream to either redirect or update.
            # Turbo Stream action redirect handles full frame redirects.
            render turbo_stream: turbo_stream.action(:redirect, return_to)
          else
            render turbo_stream: turbo_stream.action(:redirect, services_path)
          end
        end
      else
        @categories = ServiceMerchant::CATEGORIES
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @categories = ServiceMerchant::CATEGORIES
  end

  def update
    respond_to do |format|
      if @service.update(service_params)
        flash[:notice] = "Service updated successfully!"
        format.html { redirect_to services_path, notice: "Service updated successfully!" }
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, services_path) }
      else
        @categories = ServiceMerchant::CATEGORIES
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @service.subscription_plans.any?
      redirect_to services_path, alert: "Cannot delete service with active subscriptions."
    else
      @service.destroy
      redirect_to services_path, notice: "Service deleted successfully!"
    end
  end

  def seed_popular
    ServiceMerchant.seed_popular_services
    redirect_to services_path, notice: "Popular services have been added!"
  end

  private

    def determine_layout
      if turbo_frame_request?
        false
      else
        "settings"
      end
    end

    def set_service
      @service = ServiceMerchant.owned_by(Current.family).find(params[:id])
    end

    def service_params
      params.require(:service_merchant).permit(
        :name, :subscription_category, :billing_frequency,
        :default_interval_count, :default_interval_unit,
        :avg_monthly_cost, :description, :website_url
      )
    end
end
