class Course < ApplicationRecord
  include LogParameterChanges
  include Searchable
  include HasLanguage
  include HasAssociatedNodes
  include HasFriendlyId
  include CurationQueue


  has_and_belongs_to_many :content_providers
  has_many :events, dependent: :destroy
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
    text :authors do
      authors.join(" ")
    end
    text :contributors do
      authors.join(" ")
    end
    string :target_audience, multiple: true

    string :language
    string :licensing
    string :url

    time :created_at
    time :updated_at

  end

  # def self.facet_keys_with_multiple
  #   %i[keywords authors contributors target_audience language licensing node_id]
  # end

  # Facet fields for search filters
  def self.facet_fields
    field_list = %w[content_providers keywords authors contributors target_audience language licensing node]

    # Apply feature flags
    field_list.delete('node') unless TeSS::Config.feature['nodes']
    field_list.delete('node') unless TeSS::Config.feature['nodes']

    field_list
  end
end
