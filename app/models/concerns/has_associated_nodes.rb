module HasAssociatedNodes

  extend ActiveSupport::Concern

  included do
    has_many :node_links, as: :resource
    has_many :nodes, through: :node_links
  end

  def has_node?
    if self.is_a?(Event)
      nodes.any? || content_providers.any?(&:node_id)
    else
      nodes.any? || content_provider&.node_id
    end
  end

  def associated_nodes
    n = self.nodes.to_a
    if self.is_a?(Event)
      content_providers.each do |provider|
        n << provider.node if provider.node
      end
    else
      n << self.content_provider.node if self.content_provider
    end
    n.compact.uniq
  end

  def node_names= names
    nodes = Node.where('LOWER(name) IN (?)', names.map { |n| n.strip.downcase }).to_a

    self.nodes = nodes
  end

  def node_names
    nodes.map(&:name)
  end

  def associated_node_names
    associated_nodes.map(&:name)
  end

end
