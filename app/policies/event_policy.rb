class EventPolicy < ScrapedResourcePolicy

  def edit_report?
    manage?
  end

  def view_report?
    manage?
  end

  def clone?
    user.present?
  end

end
