# The controller for actions related to the resources pages
class ResourcesController < ApplicationController
  skip_before_action :authenticate_user!, :authenticate_user_from_token!

  def index; end

  def plan_design; end

  def develop; end

  def deliver; end

  def evaluate_archive; end
end
