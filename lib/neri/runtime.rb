require "neri/version"
require "pathname"
alias _neri_orig_require require
alias _neri_orig_load    load

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
  @fullpath_files = nil
  @current_directory = nil
  @xor = nil

  class << self
    def datafile=(datafile)
      
      @datafile = datafile.encode(Encoding::UTF_8)
      @system_dir = File.dirname(File.expand_path(@datafile)) + File::SEPARATOR
      files_length = File.binread(@datafile, BLOCK_LENGTH).to_i
      files_str = read(files_length, BLOCK_LENGTH)
      pos = files_length + BLOCK_LENGTH
      pos += BLOCK_LENGTH - pos % BLOCK_LENGTH unless pos % BLOCK_LENGTH == 0
      files_str.force_encoding(Encoding::UTF_8)
      files_str.split("\n").each do |line|
        filename, length, offset = line.split("\t")
        @files[filename] = [length.to_i, offset.to_i + pos]
      end

      @current_directory = nil
    end

    def key=(key)
      @xor = key.scan(/../).map { |a| a.to_i(16) }.pack("c*")
    end
    def require(feature)
      feature = feature.encode(Encoding::UTF_8)
      filepath = nil
      if exist_in_datafile?(feature) or !ENV['Neri_virtual_path']
        filepath=feature
      else
        filepath=Pathname(ENV['Neri_virtual_path']+feature).cleanpath.to_s.sub(%r{\./},"")
      end
      return _neri_orig_require(feature) unless exist_in_datafile?(filepath)
      return false if $LOADED_FEATURES.index(filepath)

      code = load_code(feature)
      eval(code, TOPLEVEL_BINDING, filepath)
      $LOADED_FEATURES.push(filepath)
      true
    end
    def load(file, priv = false)
      file = file.encode(Encoding::UTF_8)
      filepath = nil
      if exist_in_datafile?(file) or !ENV['Neri_virtual_path']
        filepath=file
      else
        filepath=Pathname(ENV['Neri_virtual_path']+file).cleanpath.to_s.sub(%r{\./},"")
      end
      return _neri_orig_load(file, priv) unless exist_in_datafile?(filepath)

      code = load_code(file)
      if priv
        Module.new.module_eval(code, filepath)
      else
        eval(code, TOPLEVEL_BINDING, filepath)
      end
      true
    end

    def file_exist?(filename)
      exist_in_datafile?(filename) || File.exist?(filename)
    end

    def file_read(filename, encoding = Encoding::BINARY)
 
      filename = filename.encode(Encoding::UTF_8)
      filepath=Pathname(ENV['Neri_virtual_path']+filename).cleanpath.to_s.sub(%r{\./},"")
      str = nil
      if exist_in_datafile?(filepath)

        length, offset = fullpath_files[File.expand_path(filepath)]
        str = read(length, offset)
      else
        str = File.binread(filename)
      end
      #p filename
      str.force_encoding(encoding)
    end

    def files
      @files.keys
    end

    def exist_in_datafile?(filename)
      filepath=Pathname(filename).cleanpath.to_s.sub(%r{\./},"") 
      return @files.has_key?(adjust_path(filepath.encode(Encoding::UTF_8)))
    end

    private

    def fullpath_files
      if @current_directory != Dir.pwd
        @current_directory = Dir.pwd
        @fullpath_files = @files.transform_keys { |k| File.expand_path(k) }
      end
      @fullpath_files
    end
    def adjust_path(path)
      return path.sub(/^\.\//, "")
    end
    def xor(str)
      str.force_encoding(Encoding::BINARY)
      str << rand(256).chr while str.bytesize % BLOCK_LENGTH != 0
      xor_str = @xor * (str.bytesize / BLOCK_LENGTH)
      return Xorcist.xor!(str, xor_str) if defined?(Xorcist)

      s = []
      str.unpack("Q*").zip((xor_str).unpack("Q*")) { |a, b| s.push(a ^ b) }
      s.pack("Q*")
    end

    def read(length, offset)
      return File.binread(@datafile, length, offset) unless @xor

      tmp_length = length
      tmp_length += BLOCK_LENGTH - length % BLOCK_LENGTH unless length % BLOCK_LENGTH == 0
      xor(File.binread(@datafile, tmp_length, offset))[0, length]
    end

    def load_path
      paths = $LOAD_PATH.map { |path| path.encode(Encoding::UTF_8) }
      return paths unless @system_dir

      paths.map { |path| path.sub(@system_dir, "*neri*#{File::SEPARATOR}") + File::SEPARATOR }
    end

    def load_code(file)

      code = file_read(file)      
      encoding = "UTF-8"
      encoding = Regexp.last_match(1) if code.lines[0..2].join("\n").match(/coding:\s*(\S+)/)
      code.force_encoding(encoding)
    end
  end
end
