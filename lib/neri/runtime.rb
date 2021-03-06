require "neri/version"

alias :_neri_orig_require :require
alias :_neri_orig_load    :load

def require(feature)
  Neri.require(feature)
end

def load(file, priv = false)
  Neri.load(file, priv)
end

module Neri
  BLOCK_LENGTH = 32
  @datafile = nil
  @system_dir = nil
  @files = {}
  @xor = nil
  
  class << self
    def datafile=(datafile)
      @datafile = datafile
      @system_dir = File.dirname(File.expand_path(datafile)) + File::SEPARATOR
      files_length = File.binread(@datafile, BLOCK_LENGTH).to_i
      files_str = read(files_length, BLOCK_LENGTH)
      pos = files_length + BLOCK_LENGTH
      pos += BLOCK_LENGTH - pos % BLOCK_LENGTH unless pos % BLOCK_LENGTH == 0
      files_str.force_encoding(Encoding::UTF_8)
      files_str.split("\n").each do |line|
        filename, length, offset = line.split("\t")
        @files[filename] = [length.to_i, offset.to_i + pos]
      end
    end
    
    def key=(key)
      @xor = key.scan(/../).map{|a| a.to_i(16)}.pack("c*")
    end
    
    def require(feature)
      filepath = nil
      load_path.each do |path|
        ["", ".rb"].each do |ext|
          next unless exist_in_datafile?(path + feature + ext)
          filepath = adjust_path(path + feature + ext)
        end
      end
      
      if filepath
        return false if $LOADED_FEATURES.index(filepath)
        code = load_code(filepath)
        eval(code, nil, filepath)
        $LOADED_FEATURES.push(filepath)
        return true
      else
        return _neri_orig_require(feature)
      end
    end
    
    def load(file, priv = false)
      filepath = nil
      (load_path + [""]).each do |path|
        filepath = path + file if exist_in_datafile?(path + file)
      end
      
      if filepath
        code = load_code(filepath)
        if priv
          Module.new.module_eval(code, filepath)
        else
          eval(code, nil, filepath)
        end
      else
        _neri_orig_load(filepath || file, priv)
      end
    end
    
    def file_exist?(filename)
      return exist_in_datafile?(filename) || File.exist?(filename)
    end
    
    def file_read(filename, encoding = Encoding::BINARY)
      str = nil
      if exist_in_datafile?(filename)
        length, offset = @files[adjust_path(filename.encode(Encoding::UTF_8))]
        str = read(length, offset)
      else
        str = File.binread(filename)
      end
      str.force_encoding(encoding)
      return str
    end
    
    def files()
      return @files.keys
    end
    
    def exist_in_datafile?(filename)
      return @files.has_key?(adjust_path(filename.encode(Encoding::UTF_8)))
    end
    
    private
    
    def xor(str)
      str.force_encoding(Encoding::BINARY)
      while str.bytesize % BLOCK_LENGTH != 0
        str << rand(256).chr
      end
      if defined?(Xorcist)
        return Xorcist.xor!(str, @xor * (str.bytesize / BLOCK_LENGTH))
      else
        s = []
        str.unpack("Q*").zip((@xor * (str.bytesize / BLOCK_LENGTH)).unpack("Q*")){|a, b| s.push(a ^ b)}
        return s.pack("Q*")
      end
    end
    
    def adjust_path(path)
      return path.sub(/^\.\//, "")
    end
    
    def read(length, offset)
      if @xor
        tmp_length = length
        tmp_length += BLOCK_LENGTH - length % BLOCK_LENGTH unless length % BLOCK_LENGTH == 0
        return xor(File.binread(@datafile, tmp_length, offset))[0, length]
      else
        return File.binread(@datafile, length, offset)
      end
    end
    
    def load_path()
      return $LOAD_PATH unless @system_dir
      return $LOAD_PATH.map{|path| path.sub(@system_dir, "*neri*#{File::SEPARATOR}") + File::SEPARATOR }
    end
    
    def load_code(file)
      code = file_read(file)
      encoding = "UTF-8"
      encoding = $1 if code.lines[0..2].join("\n").match(/coding:\s*(\S+)/)
      code.force_encoding(encoding)
      return code
    end
  end
end
