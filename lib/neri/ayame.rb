require "neri/runtime"

require "ayame" unless defined? Ayame

class Ayame
  class << self
    alias :_neri_orig_new :new
    
    def new(filename)
      if Neri.exist_in_datafile?(filename)
        ayame = load_from_memory(Neri.file_read(path))
        return ayame
      else
        return _neri_orig_new(filename)
      end
    end
  end
end
