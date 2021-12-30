require "neri/version"
require "pathname"

module Kernel
  unless defined?(neri_original_require)
    alias    neri_original_require require
    private :neri_original_require
  end

  unless defined?(neri_original_load)
    alias    neri_original_load load
    private :neri_original_load
  end

  def require(feature)
    Neri.require(feature)
  end

  def load(file, priv = false)
    Neri.load(file, priv)
  end
end

module Neri
  BLOCK_LENGTH = 32
  @datafile = nil
  @file_informations = {}
  @fullpath_files = {}
  @virtual_files = {}
  @virtual_directory = "."
  @xor = nil

  class << self
    def datafile=(datafile)
      @datafile = datafile.encode(Encoding::UTF_8)
      files_length = File.binread(@datafile, BLOCK_LENGTH).to_i
      files_str = read(files_length, BLOCK_LENGTH)
      pos = files_length + BLOCK_LENGTH
      pos += BLOCK_LENGTH - pos % BLOCK_LENGTH unless pos % BLOCK_LENGTH == 0
      files_str.force_encoding(Encoding::UTF_8)
      files_str.each_line do |line|
        filename, length, offset = line.split("\t")
        @file_informations[filename] = [length.to_i, offset.to_i + pos]
      end
      @fullpath_files = @file_informations.transform_keys { |k| File.expand_path(k) }
    end

    def key=(key)
      @xor ||= key.scan(/../).map { |a| a.to_i(16) }.pack("c*")
    end

    def virtual_directory=(path)
      @virtual_directory = path
      @virtual_files = @file_informations.transform_keys { |k| File.expand_path(k, path) }
    end

    def require(feature)
      feature_path = Pathname.new(feature.encode(Encoding::UTF_8))
      feature_path = feature_path.sub_ext(".rb") if feature_path.extname == ""
      return neri_original_require(feature) if feature_path.extname == ".so"

      path_str = if feature_path.absolute? || feature.start_with?(".")
                   path_in_datafile(feature_path)
                 else
                   search_in_load_path(feature_path)
                 end

      return neri_original_require(feature) unless path_str
      return false if $LOADED_FEATURES.index(path_str)

      code = load_code(path_str)
      eval(code, TOPLEVEL_BINDING, path_str)
      $LOADED_FEATURES.push(path_str)
      true
    end

    def load(file, priv = false)
      file_path = Pathname.new(file.encode(Encoding::UTF_8))
      path_str = search_in_load_path(file_path) if file_path.relative? && !file.start_with?(".")
      path_str ||= path_in_datafile(file_path)

      return neri_original_load(file, priv) unless path_str

      code = load_code(path_str)
      if priv
        Module.new.module_eval(code, path_str)
      else
        eval(code, TOPLEVEL_BINDING, path_str)
      end
      true
    end

    def file_exist?(filename)
      exist_in_datafile?(filename) || File.exist?(filename)
    end

    def file_read(filename, encoding = Encoding::BINARY)
      filename = filename.encode(Encoding::UTF_8)
      length, offset = file_information(filename)
      str = length ? read(length, offset) : File.binread(filename)
      str.force_encoding(encoding)
    end

    def files
      @file_informations.keys
    end

    def exist_in_datafile?(filename)
      file_information(filename) != nil
    end

    private

    def file_information(filename)
      fullpath = File.expand_path(filename)
      return @fullpath_files[fullpath] if @fullpath_files.key?(fullpath)

      @virtual_files[File.expand_path(filename, @virtual_directory)]
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

    def search_in_load_path(file_path)
      $LOAD_PATH.each do |path_str|
        path_str = path_str.dup.force_encoding(Encoding::UTF_8) if path_str.encoding == Encoding::BINARY
        load_path = Pathname.new(path_str.encode(Encoding::UTF_8))
        candidate_path_str = path_in_datafile(load_path + file_path)
        return candidate_path_str if candidate_path_str
      end
      nil
    end

    def path_in_datafile(file_path)
      fullpath = File.expand_path(file_path.to_s)
      return fullpath if exist_in_datafile?(fullpath)

      virtual_path = File.expand_path(file_path.to_s, @virtual_directory)
      exist_in_datafile?(virtual_path) ? virtual_path : nil
    end

    def load_code(file)
      code = file_read(file)
      encoding = "UTF-8"
      encoding = Regexp.last_match(1) if code.lines[0..2].join("\n").match(/coding:\s*(\S+)/)
      code.force_encoding(encoding)
    end
  end
end
