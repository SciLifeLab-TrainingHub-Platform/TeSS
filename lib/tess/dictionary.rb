module Tess
  class Dictionary

    include Singleton

    def initialize
      @dictionary = load_dictionary
    end

    def lookup(id)
      @dictionary[id]
    end

    # Find the value for the given key, for the given entry.
    # Returns nil if no entry found or the entry doesn't contain that key.
    #  e.g.
    #    Tess::LicenceDictionary.instance.lookup_value('GPL-3.0', 'title') => "GNU General Public License 3.0"
    #    Tess::LicenceDictionary.instance.lookup_value('GPL-3.0', 'fish') => nil
    #    Tess::LicenceDictionary.instance.lookup_value('fish', 'title') => nil
    #    Tess::LicenceDictionary.instance.lookup_value('fish', 'fish') => nil
    #
    def lookup_value(id, key)
      lookup(id).try(:[], key)
    end

    def options_for_select(existing = nil)
      if existing
        d = @dictionary.select { |key, value| existing.include?(key) }
      else
        d = @dictionary
      end

      d.map do |key, value|
        [value['title'], key]
      end
    end

    def values_for_search(keys)
      @dictionary.select { |key, value| keys.include?(key) }.map { |key, value| value['title'] }
    end

    private

    def load_dictionary
      YAML.load(File.read(dictionary_filepath))
    end

  end
end