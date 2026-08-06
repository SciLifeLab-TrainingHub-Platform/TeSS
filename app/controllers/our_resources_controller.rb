# The controller for actions related to the resources pages
class OurResourcesController < ApplicationController
  skip_before_action :authenticate_user!, :authenticate_user_from_token!
  before_action :set_breadcrumbs, only: %i[guides pedagogic_support trainer_community fair_training]

  def our_resources; end

  def design_develop; end

  def develop; end

  def deliver; end

  def evaluate_archive; end

  def guides
    @breadcrumbs += [{ name: 'Training Assets', url: guides_path }]
  end

  def pedagogic_support
    @breadcrumbs += [{ name: 'Support', url: pedagogic_path }]
  end

  def trainer_community
    @breadcrumbs += [{ name: 'Community', url: community_path }]
  end

  def fair_training
    @breadcrumbs += [{ name: 'FAIR', url: fair_path }]
  end

  private

  def set_breadcrumbs
    @breadcrumbs = []
    add_breadcrumb 'Home', root_path
    add_breadcrumb 'Our resources', our_resources_path
  end
end
