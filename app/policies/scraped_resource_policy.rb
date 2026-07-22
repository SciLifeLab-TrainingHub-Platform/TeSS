# A policy specific to things that have been scraped. Events and Materials

class ScrapedResourcePolicy < ResourcePolicy
  def manage?
    super || (@user && @user.is_curator?) || is_content_provider_editor?
  end

  private

  def is_content_provider_editor?
    providers = []

    # If @record is a ContentProvider, use it directly
    if @record.is_a?(ContentProvider)
      providers << @record
    end

    # Handle cases where @record has a single content_provider
    if @record.respond_to?(:content_provider)
      providers << @record.content_provider if @record.content_provider
    end

    # Handle cases where @record has multiple content_providers
    if @record.respond_to?(:content_providers)
      providers.concat(@record.content_providers)
    end

    # Check if the user is the owner or an editor of any provider
    providers.any? do |provider|
      provider.user == @user || provider.editors.include?(@user)
    end
  end
end
