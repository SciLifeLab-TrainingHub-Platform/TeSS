class Course < ApplicationRecord
  include PublicActivity::Common
  include LogParameterChanges
  include Searchable
  include HasLanguage
  include HasAssociatedNodes
  include HasFriendlyId
  include CurationQueue
  include HasLicence

  has_and_belongs_to_many :content_providers
  has_many :events, dependent: :nullify
  belongs_to :user

  if TeSS::Config.solr_enabled
    searchable do
      text :title, :description, :learning_outcomes, :structure_and_duration, :prerequisites_knowledge, :prerequisites_technical
      string :content_providers, multiple: true do
        content_providers.pluck(:title)
      end
      string :keywords, multiple: true
      string :sort_title do
        title.downcase.gsub(/^(an?|the) /, '')
      end
      string :node, multiple: true do
        associated_nodes.pluck(:name)
      end

      string :target_audience, multiple: true

      string :language
      string :licence
      string :url

      time :created_at
      time :updated_at

    end
  end


  validates :title, :url, :language, :description,
            :structure_and_duration, :learning_outcomes,
            :prerequisites_knowledge, :prerequisites_technical,
            presence: true

  validates :target_audience, presence: true
  validates :content_providers, presence: true
  validates :node_ids, presence: true, if: -> { TeSS::Config.feature['nodes'] && Node.all.count > 0  }
  clean_array_fields(:keywords, :target_audience)


  # Facet fields for search filters
  def self.facet_fields
    field_list = %w[content_providers keywords target_audience language licence node]

    # Apply feature flags
    field_list.delete('node') unless TeSS::Config.feature['nodes']

    field_list
  end

  def self.check_exists(course_params)
    check_exists_candidates(course_params).first
  end

  def self.check_exists_candidates(course_params)
    title, url, provider_ids = extract_check_exists_attributes(course_params)

    scope = if provider_ids.any?
              joins(:content_providers).where(content_providers: { id: provider_ids }).distinct
            else
              all
            end

    if url.present?
      url_matches = scope.where(url: url).order(id: :desc)
      return url_matches if url_matches.exists?
    end

    return scope.where(title: title).order(id: :desc) if title.present?

    none
  end

  def self.extract_check_exists_attributes(course_params)
    if course_params.is_a?(Course)
      title = course_params.title
      url = course_params.url
      provider_ids = course_params.content_provider_ids
    else
      params_hash = course_params.to_h.with_indifferent_access
      title = params_hash[:title]
      url = params_hash[:url]

      provider_ids = Array(params_hash[:content_provider_ids]).reject(&:blank?)
      provider_ids += Array(params_hash[:content_provider_id]).reject(&:blank?)
      provider_ids = provider_ids.map(&:to_i).reject(&:zero?).uniq
    end

    [title, url, provider_ids]
  end
  private_class_method :extract_check_exists_attributes
end
