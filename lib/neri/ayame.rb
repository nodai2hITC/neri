require "neri/runtime"

require "ayame" unless defined? Ayame

module Neri
  module Ayame
    def new(filename)
      return super unless Neri.exist_in_datafile?(filename)

      load_from_memory(Neri.file_read(filename))
    end
  end
end

class Ayame
  class << self
    prepend Neri::Ayame
  end
end
