require "neri/runtime"

require "dxruby_tiled" unless defined? DXRuby::Tiled

module DXRuby
  module Tiled
    def self.load_json(jsonfile, encoding = "UTF-8", dir = nil)
      return Map.new(JSON.load(Neri.file_read(jsonfile, encoding), nil,
                                symbolize_names: true, create_additions: false),
                      dir || File.dirname(jsonfile))
    end
  end
end
