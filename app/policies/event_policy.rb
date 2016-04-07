class EventPolicy < ApplicationPolicy

  def update?
    # Admin role can update/destroy any object, other roles can only update objects they created
    return true if @user.is_admin? # allow admin roles for all requests - UI and API
    if request_is_api?(@request) #is this an API action - allow api_user roles only
      if @user.has_role?(:api_user) and @user.is_owner?(@record) # check ownership
        return true
      else
        return false
      end
    end
    if @user.is_owner?(@record) # check ownership
      return true
    else
      return false
    end
  end

  def edit?
    update?
  end

  def destroy?
    update?
  end

  class Scope < Scope
    def resolve
      Event.all
    end
  end
end
