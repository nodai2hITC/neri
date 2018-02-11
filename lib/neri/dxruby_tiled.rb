require "neri/runtime"

require "dxruby_tiled" unless defined? DXRuby::Tiled

module DXRuby
  module Tiled
    module_function
    
    def read_file(file, encoding = Encoding::UTF_8)
      Neri.file_read(file, encoding)
    end
  end
end
