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
    given_course = self.new(course_params)
    course = nil

    if given_course.url.present?
      course = self.find_by_url(given_course.url)
    end

    if given_course.title.present?
      course ||= self.where(title: given_course.title).last
    end

    course
  end
end
