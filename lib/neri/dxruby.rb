require "neri/runtime"

require "dxruby" unless defined? DXRuby

module Neri
  module DXRubyImage
    def load(path, x = nil, y = nil, width = nil, height = nil)
      return super unless Neri.exist_in_datafile?(path)

      image = load_from_file_in_memory(Neri.file_read(path))
      image = image.slice(x, y, width, height) if x && y && width && height
      image
    end

    def load_tiles(path, xcount, ycount, share_switch = true)
      return super unless Neri.exist_in_datafile?(path) && !share_switch

      image = load_from_file_in_memory(Neri.file_read(path))
      image.slice_tiles(xcount, ycount)
    end
  end

  module DXRubySound
    def new(path)
      return super unless Neri.exist_in_datafile?(path)

      load_from_memory(Neri.file_read(path),
                       File.extname(path) == ".mid" ? DXRuby::TYPE_MIDI : DXRuby::TYPE_WAV)
    end
  end
end

module DXRuby
  class Image
    class << self
      prepend Neri::DXRubyImage
    end
  end

  class Sound
    class << self
      prepend Neri::DXRubySound
    end
  end
end
