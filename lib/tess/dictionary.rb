module Tess
  class Dictionary

    include Singleton

    def initialize
      @dictionary = load_dictionary
    end

    def lookup(key)
      @dictionary[key]
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
