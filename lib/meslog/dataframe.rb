module Meslog
  class Dataframe
    attr_accessor :preset_params
    attr_accessor :const_params
    attr_reader :axis_path
    attr_reader :data_paths

    def initialize(axis_path, data_paths)
      @records = Hash.new
      @axis_path = axis_path
      @data_paths = data_paths
      @preset_params = Hash.new
      @const_params = Hash.new
    end

    def [](key)
      if @records.has_key?(key)
        record = @records[key]
      else
        record = Hash.new
        @records[key] = record
      end

      record
    end

    def each
      @records.each do |key,val|
        yield(key, val)
      end
    end
  end
end
