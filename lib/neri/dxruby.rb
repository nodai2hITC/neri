require "neri/runtime"

require "dxruby" unless defined? DXRuby

module Neri
  module DXRubyImage
    def load(path, x=nil, y=nil, width=nil, height=nil)
      if Neri.exist_in_datafile?(path)
        image = load_from_file_in_memory(Neri.file_read(path))
        image = image.slice(x, y, width, height) if x && y && width && height
        return image
      else
        return super
      end
    end
    
    def load_tiles(path, xcount, ycount, share_switch=true)
      if Neri.exist_in_datafile?(path) && !share_switch
        image = load_from_file_in_memory(Neri.file_read(path))
        return image.slice_tiles(xcount, ycount)
      else
        return super
      end
    end
  end
  
  module DXRubySound
    def new(path)
      if Neri.exist_in_datafile?(path)
        case File.extname(path)
        when ".mid"
          return load_from_memory(Neri.file_read(path), DXRuby::TYPE_MIDI)
        else
          return load_from_memory(Neri.file_read(path), DXRuby::TYPE_WAV)
        end
      else
        return super
      end
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
