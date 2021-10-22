require "neri/runtime"

require "ayame" unless defined? Ayame

module Neri
  module Ayame
    def new(filename)
      if Neri.exist_in_datafile?(filename)
        ayame = load_from_memory(Neri.file_read(filename))
        return ayame
      else
        return super
      end
    end
  end
end

class Ayame
  class << self
    prepend Neri::Ayame
  end
end
