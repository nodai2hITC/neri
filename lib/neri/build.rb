#!/usr/bin/env ruby
# encoding: UTF-8

require "neri"

module Neri
  @data_files = []
  @system_files = []
  
  @options = {
    quiet:   false,
    verbose: false,
    
    dlls:     [],
    libs:     [],
    gems:     [],
    encoding: "*",
    
    enable_gems:         false,
    enable_did_you_mean: false,
    chdir_first:         false,
    pause_last:          nil,
    pause_text:          nil,
    
    output_dir: nil,
    system_dir: "system",
    
    data_file:      nil,
    encryption_key: nil,
    
    no_exe:    false,
    b2ec_path: "Bat_To_Exe_Converter.exe",
    b2ec: {
      icon: "#{File.expand_path(File.dirname(__FILE__) + '/../../share/default.ico')}",
      invisible:      nil,
      x64:            nil,
      admin:          nil,
      fileversion:    nil,
      productversion: nil,
      company:        nil,
      productname:    nil,
      internalname:   nil,
      description:    nil,
      copyright:      nil
    },
    
    use_upx:     false,
    upx_path:    "upx.exe",
    upx_targets: ["bin/**/*.dll"],
    upx_options: "",
    
    zipfile:       nil,
    sevenzip_path: "7z.exe",
    
    inno_script: nil,
    iscc_path:   "iscc",
  }
  @rubyopt = ENV["RUBYOPT"].to_s
  @encryption_key = nil
  
  @use_dxruby       = false
  @use_dxruby_tiled = false
  @use_ayame        = false

  class << self
    
    attr_reader :options
    
    def relative_path(path, basedir=rubydir, prepath = "")
      basedir.concat(File::SEPARATOR) unless basedir.end_with?(File::SEPARATOR)
      return path.start_with?(basedir) ? path.sub(basedir, prepath) : path
    end
    
    def to_winpath(path)
      return File::ALT_SEPARATOR ? path.tr(File::SEPARATOR, File::ALT_SEPARATOR) : path
    end
    
    def bindir(   ); RbConfig::CONFIG["bindir"] || File.join(rubydir, "bin"); end
    def rubydir(  ); RbConfig::TOPDIR; end
    def rubyexe(  ); RbConfig.ruby; end
    def batchfile(); File.join(options[:output_dir], "#{File.basename(@data_files.first, ".*")}.bat"); end
    def datafile( ); File.join(options[:output_dir], options[:system_dir], options[:data_file]); end
    
    # --help
    def output_help
      puts <<-EOF
usage: neri [options] script.rb (other_files...) -- script_arguments

options:
  --help or -h
  --version or -v
  --quiet
  --verbose
  
  --dll <dll1>,<dll2>,...
  --lib <lib1>,<lib2>,...
  --gem <gem1>,<gem2>,...
  
  --no-enc
  --encoding <enc1>,<enc2>,...
  
  --enable-gems
  --enable-did-you-mean
  --chdir-first
  --pause-last
  --no-pause-last
  --pause-text <text>
  
  --output-dir <dirname>
  --system-dir <dirname>
  --data-file <filename>
  --encryption-key <key>
  
  --no-exe
  --b2ec-path <bat_to_exe_converter_path>
  --icon <iconfile>
  --windows or --invisible
  --console or --visible
  --x64
  --admin
  --fileversion <version>     # ex) 1,2,3,4
  --productversion <version>  # ex) 1,2,3,4
  --company <company_name>
  --productname <name>
  --internalname <name>
  --description <description>
  --copyright <copyright>
  
  --use-upx
  --upx-path <upx path>
  --upx_targets '<glob>'  # ex) 'bin/**/*.dll'
  --upx-options <options>
  
  --zipfile <filename>
  --7zip-path <7-zip path>
  
  --innosetup <inno_script>
  --iscc-path <iscc path>
  
  --create-recipe <recipefile>
  --recipe <recipefile>
      EOF
    end
    
    # --version
    def output_version
      puts "Neri #{Neri::VERSION}"
    end
    
    # --create-recipe
    def create_recipe(file, hash = options, pre = "Neri.options")
      hash.each_pair do |key, value|
        case value
        when Hash
          create_recipe(file, value, pre + "[:#{key}]")
        when Numeric, TrueClass, FalseClass
          file.puts "#{pre}[:#{key}] = #{value}"
        when NilClass
          file.puts "#{pre}[:#{key}] = nil"
        when String
          file.puts "#{pre}[:#{key}] = '#{value.gsub("\\", "\\\\").gsub("'", "\\'")}'"
        when Array
          file.puts "#{pre}[:#{key}] = " + JSON.generate(value)
        end
      end
    end
    
    
    def check_options
      nputs_v "Checking Neri options."
      while arg = ARGV.shift
        case arg
        when "--help", "-h"
          output_help
          exit
        when "--version", "-v"
          output_version
          exit
        when "--quiet", "-q"
          options[:quiet] = true
        when "--verbose", "-v"
          options[:verbose] = true
        when "--dll"
          options[:dlls] += ARGV.shift.split(/\s*,\s*/)
        when "--lib"
          options[:libs] += ARGV.shift.split(/\s*,\s*/)
        when "--gem"
          options[:gems] += ARGV.shift.split(/\s*,\s*/)
        when "--no-enc"
          options[:encoding] = nil
        when "--encoding"
          options[:encoding] = ARGV.shift
        when "--enable-gems"
          options[:enable_gems] = true
        when "--enable-did-you-mean"
          options[:enable_did_you_mean] = true
        when "--chdir-first"
          options[:chdir_first] = true
        when "--pause-last"
          options[:pause_last] = true
        when "--no-pause-last"
          options[:pause_last] = false
        when "--pause-text"
          options[:pause_text] = ARGV.shift
          options[:pause_last] = true
        when "--output-dir"
          options[:output_dir] = ARGV.shift
        when "--system-dir"
          options[:system_dir] = ARGV.shift
        when "--data-file"
          options[:data_file] = ARGV.shift
        when "--encryption-key"
          options[:encryption_key] = ARGV.shift
        when "--no-exe"
          options[:no_exe] = true
        when "--b2ec-path"
          options[:b2ec_path] = ARGV.shift
        when "--icon"
          options[:b2ec][:icon] = ARGV.shift
        when "--windows", "--invisible"
          options[:b2ec][:invisible] = true
        when "--console", "--visible"
          options[:b2ec][:invisible] = false
        when "--x64"
          options[:b2ec][:x64] = true
        when "--admin"
          options[:b2ec][:admin] = true
        when "--fileversion"
          options[:b2ec][:fileversion] = ARGV.shift
        when "--productversion"
          options[:b2ec][:productversion] = ARGV.shift
        when "--company"
          options[:b2ec][:company] = ARGV.shift
        when "--productname"
          options[:b2ec][:productname] = ARGV.shift
        when "--internalname"
          options[:b2ec][:internalname] = ARGV.shift
        when "--description"
          options[:b2ec][:description] = ARGV.shift
        when "--copyright"
          options[:b2ec][:copyright] = ARGV.shift
        when "--use-upx"
          options[:use_upx] = true
        when "--upx-path"
          options[:upx_path] = ARGV.shift
        when "--upx-targets"
          options[:upx_targets] += ARGV.shift.split(/\s*,\s*/)
        when "--upx-options"
          options[:upx_options] = ARGV.shift
        when "--zipfile"
          options[:zipfile] = ARGV.shift
        when "--7zip-path"
          options[:sevenzip_path] = ARGV.shift
        when "--innosetup"
          options[:inno_script] = ARGV.shift
        when "--iscc-path"
          options[:iscc_path] = ARGV.shift
        when "--create-recipe"
          require "json"
          filename = ARGV.shift
          nputs "Creating recipe_file '#{filename}'."
          open(filename, "w:utf-8"){|file| create_recipe(file)}
          exit
        when "--recipe"
          filename = ARGV.shift
          nputs_v "Loading recipe_file '#{filename}'."
          load filename
        when "--"
          break
        when /^(--.+)/
          puts "** Invalid Option '#{arg}'! **"
          output_help
          exit
        else
          @data_files.push(arg)
        end
      end
      
      if @data_files.empty?
        puts "** No Script File! **"
        output_help
        exit
      end
      
      if @data_files.size > 1 || options[:encryption_key]
        options[:data_file] ||= File.basename(@data_files.first, ".*") + ".dat"
      end
    end
    
    
    # check dependencies
    def rb_dependencies()
      return $LOADED_FEATURES.uniq
    end
    
    def dll_dependencies()
      require "Win32API"
      
      enumprocessmodules = Win32API.new("psapi"   , "EnumProcessModules", ["L","P","L","P"], "L")
      getmodulefilename  = Win32API.new("kernel32", "GetModuleFileNameW", ["L","P","L"], "L")
      getcurrentprocess  = Win32API.new("kernel32", "GetCurrentProcess" , [], "L")
      
      bytes_needed = 4 * 32
      module_handle_buffer = nil
      process_handle = getcurrentprocess.call()
      loop do
        module_handle_buffer = "\x00" * bytes_needed
        bytes_needed_buffer = [0].pack("I")
        r = enumprocessmodules.call(process_handle, module_handle_buffer, module_handle_buffer.size, bytes_needed_buffer)
        bytes_needed = bytes_needed_buffer.unpack("I")[0]
        break if bytes_needed <= module_handle_buffer.size
      end
      
      handles = module_handle_buffer.unpack("I*")
      dependencies = handles.select { |handle| handle > 0 }.map do |handle|
        str = "\x00\x00" * 256
        modulefilename_length = getmodulefilename.call(handle, str, str.size)
        modulefilename = str[0, modulefilename_length * 2].force_encoding("UTF-16LE").encode("UTF-8")
      end
      
      dependencies.map!{|dep| dep.sub(/^\\\\\?\\/, "")}
      if File::ALT_SEPARATOR
        dependencies.map!{|dep| dep.tr(File::ALT_SEPARATOR, File::SEPARATOR)}
      end
      dependencies.delete(rubyexe)
      
      return dependencies.uniq
    end
    
    def ruby_dependencies()
      dependencies = Dir.glob(File.join(bindir, "**", "*.manifest"))
      dependencies.push(rubyexe)
      return dependencies.uniq
    end
    
    def additional_dlls_dependencies()
      dependencies = []
      options[:dlls].each do |dll|
        dependencies += Dir.glob(File.join(bindir, "**", dll))
        dependencies += Dir.glob(File.join(bindir, "**", dll + ".*"))
      end
      return dependencies.uniq
    end
    
    def additional_libs_dependencies()
      dependencies = []
      options[:libs].each do |lib|
        $LOAD_PATH.each do |path|
          dependencies += Dir.glob(File.join(path, lib))
          dependencies += Dir.glob(File.join(path, lib + ".*"))
          dependencies += Dir.glob(File.join(path, lib, "**", "*"))
        end
      end
      return dependencies.uniq
    end
    
    def additional_gems_dependencies()
      require "rubygems"
      dependencies = []
      rubygems_dir = File.join(Gem.dir, "gems")
      options[:gems].each do |gem|
        gem.sub!(/\:(.+)/, "")
        targets = $1.to_s.split("|")
        targets.push("lib/**/*")
        gem += "-*" unless gem.match("-")
        gemdir = Dir.glob(File.join(rubygems_dir, gem)).sort.last
        next unless gemdir
        targets.each do |target|
          dependencies += Dir.glob(File.join(gemdir, target))
        end
      end
      return dependencies.uniq
    end
    
    def encoding_dependencies()
      return [] unless options[:encoding]
      dependencies = []
      enc_dir = Dir.glob(File.join(RbConfig::CONFIG["archdir"] || RbConfig::TOPDIR, "**", "enc")).first
      
      options[:encoding].split(/\s*,\s*/).each do |enc|
        case enc
        when "ja"
          %w[windows_31j.so japanese_sjis.so encdb.so].each do |enc_name|
            dependencies += Dir.glob(File.join(enc_dir, "**", enc_name))
          end
        else
          dependencies += Dir.glob(File.join(enc_dir, "**", enc))
          dependencies += Dir.glob(File.join(enc_dir, "**", enc + ".*"))
        end
      end
      
      return dependencies.uniq
    end
    
    def check_dependencies()
      nputs "Running script '#{@data_files.first}' to check dependencies."
      begin
        load @data_files.first
      rescue SystemExit
      end
      nputs "Script '#{@data_files.first}' end."

      if defined? DXRuby
        require "neri/dxruby"
        @use_dxruby = true
        options[:b2ec][:invisible] = true if options[:b2ec][:invisible] == nil
      end
      if defined? DXRuby::Tiled
        require "neri/dxruby_tiled"
        @use_dxruby_tiled = true
      end
      if defined? Ayame
        require "neri/ayame"
        @use_ayame = true
      end

      if options[:b2ec][:invisible] == nil
        options[:b2ec][:invisible] = true if File.extname(@data_files.first) == ".rbw"
      end
      if options[:pause_last] == nil
        options[:pause_last] = true unless options[:b2ec][:invisible]
      end
      
      require "rbconfig"
      dependencies = []
      dependencies += rb_dependencies
      dependencies += dll_dependencies
      dependencies += ruby_dependencies
      dependencies += additional_dlls_dependencies
      dependencies += additional_libs_dependencies
      dependencies += additional_gems_dependencies
      dependencies += encoding_dependencies
      dependencies = select_dependencies(dependencies)

      size = dependencies.map{|d| File.size(d)}.inject(&:+)
      nputs "#{dependencies.size} files, #{size} bytes dependencies."
      if options[:verbose]
        dependencies.each do |dependency|
          nputs_v "  - #{dependency}"
        end
      end

      return dependencies
    end
    
    def select_dependencies(dependencies)
      dependencies.select! do |dependency|
        dependency.start_with?(rubydir + File::SEPARATOR)
      end
      
      @data_files.each do |file|
        dependencies.delete(File.expand_path(file))
      end
      
      unless options[:enable_gems]
        dependencies.delete_if do |dependency|
          File.basename(dependency) == "rubygems.rb" ||
          dependency.split(File::SEPARATOR).index("rubygems")
        end
      end
      unless options[:enable_did_you_mean]
        dependencies.delete_if do |dependency|
          File.basename(dependency) == "did_you_mean.rb" ||
          dependency.split(File::SEPARATOR).index("did_you_mean")
        end
      end
      
      return dependencies.uniq
    end
    
    
    def copy_files(dependencies)
      nputs "Copying dependencies."
      require "fileutils"
      options[:output_dir] ||= File.basename(@data_files.first, ".*")
      src_dir  = File.join(rubydir, "")
      desc_dir = File.join(options[:output_dir], options[:system_dir], "")
      
      @system_files = dependencies.map do |file|
        [file, file.sub(src_dir, desc_dir)]
      end
      unless options[:enable_gems]
        @system_files.each do |src, desc|
          desc.sub!(/\/gems(\/\d+\.\d+\.\d+\/)gems\/(.+?)\-[^\/]+\/lib\//, "/vendor_ruby\\1")
        end
      end
      
      @system_files.each do |src, desc|
        FileUtils.makedirs(File.dirname(desc))
        if File.file?(src)
          FileUtils.copy(src, desc)
          nputs_v "  #{src}\n  -> #{desc}"
        end
      end
      FileUtils.copy(@data_files.first, desc_dir) unless options[:data_file]
    end
    
    
    def create_batch()
      nputs "Creating batch_file '#{batchfile}'."
      
      enc = system(%(ruby --disable-gems -e "'#{@data_files.first}'" >NUL 2>&1)) ?
        '' : ' -e "# coding: utf-8"'
      
        unless options[:enable_gems]
        @rubyopt += " --disable-gems" unless @rubyopt.match("--disable-gems")
      end
      
      ruby_code = ""
      if options[:encryption_key]
        require "digest/sha2"
        @encryption_key = Digest::SHA2.hexdigest(options[:encryption_key])
        ruby_code = "Neri.key='#{@encryption_key}';"
      end
      if options[:data_file]
        data_file = "%~dp0#{options[:system_dir]}#{File::ALT_SEPARATOR || File::SEPARATOR}#{options[:data_file]}"
        ruby_code += "Neri.datafile='#{data_file}';"
        ruby_code += "load '#{File.basename(@data_files.first)}'"
      else
        ruby_code += "load '%~dp0#{options[:system_dir]}#{File::ALT_SEPARATOR}#{File.basename(@data_files.first)}'"
      end
      
      pause_code = ""
      if options[:pause_last]
        if options[:pause_text]
          pause_code = "echo.\necho #{options[:pause_text]}\npause > nul"
        else
          pause_code = "echo.\npause"
        end
      end
      
      r  = " -rneri"
      r += " -rneri/dxruby"       if @use_dxruby
      r += " -rneri/dxruby_tiled" if @use_dxruby_tiled
      r += " -rneri/ayame"        if @use_ayame
      
      open(batchfile, "w:#{Encoding.default_external.name}") do |f|
        f.puts <<-EOF
@echo off
setlocal
set PATH=%~dp0#{options[:system_dir]}\\#{relative_path(bindir)};%PATH%
#{options[:chdir_first] ? 'cd /d "%~dp0"' : ''}
if %~x0 == .exe ( shift )
#{relative_path(rubyexe, bindir)}#{r} #{@rubyopt}#{enc} -e "#{ruby_code}"
#{pause_code}
endlocal
        EOF
      end
    end
    
    
    def create_datafile()
      nputs "Creating data_file '#{datafile}'."
      data_files = @data_files.select { |file| File.file? file }
      @data_files.select { |file| File.directory? file }.each do |dir|
        data_files += Dir.glob(dir + "/**/*").select { |file| File.file? file }
      end
      Neri.key = @encryption_key || "0" * 64
      open(datafile, "wb") do |f|
        pos = 0
        files_str = data_files.map{|file|
          filename = File.expand_path(file)
          filename = relative_path(filename, rubydir, "*neri*" + File::SEPARATOR)
          filename = relative_path(filename, Dir.pwd)
          filedata = [filename, File.size(file), pos]
          pos += File.size(file)
          pos += BLOCK_LENGTH - pos % BLOCK_LENGTH unless pos % BLOCK_LENGTH == 0
          nputs_v "  - #{filename}:#{File.size(file)} bytes"
          filedata.join("\t")
        }.join("\n").encode(Encoding::UTF_8)
        
        f.write(sprintf("%#{BLOCK_LENGTH}d", files_str.bytesize))
        f.write(xor(files_str))
        data_files.each do |file|
          f.write(xor(File.binread(file)))
        end
      end
    end
    
    
    def bat_to_exe_converter()
      exefile = batchfile.sub(/\.bat$/, ".exe")
      nputs "Creating exe_file '#{exefile}'."
      File.delete(exefile) if File.exist?(exefile)
      options[:b2ec][:bat] = batchfile
      options[:b2ec][:save] = exefile
      if options[:b2ec][:x64] == nil
        options[:b2ec][:x64] = true if RbConfig::CONFIG["target"].to_s.index("64")
      end
      
      args = options[:b2ec].map{|key, value|
        case value
        when String; " -#{key.to_s} \"#{value}\""
        when true;   " -#{key.to_s}"
        else;        ""
        end
      }.join("")
      begin
        exec = %(#{options[:b2ec_path]}#{args})
        nputs_v exec
        options[:quiet] ? `#{exec}` : system(exec)
      rescue SystemCallError
      end
      if File.exist?(exefile)
        File.delete(batchfile)
      else
        nputs "Failed to create exe_file."
      end
    end
    
    
    def upx()
      nputs "Compressing with UPX."
      options[:upx_targets].each do |target|
        Dir.glob(File.join(options[:output_dir], options[:system_dir], target)).each do |target_path|
          exec = %(#{options[:upx_path]} #{options[:upx_options]} "#{target_path}")
          nputs_v exec
          options[:quiet] ? `#{exec}` : system(exec)
        end
      end
    end
    
    
    def create_zipfile()
      nputs "Creating zip_file '#{options[:zipfile]}'."
      File.delete(options[:zipfile]) if File.exist?(options[:zipfile])
      exec = %(#{options[:sevenzip_path]} a #{options[:zipfile]} "#{options[:output_dir]}")
      nputs_v exec
      options[:quiet] ? `#{exec}` : system(exec)
    end
    
    
    def inno_setup()
      filename = options[:inno_script]
      script = "[Setup]\n"
      if File.exist?(filename)
        script = File.read(filename, encoding: Encoding::UTF_8)
        filename = File.basename(filename, ".*") + "_tmp" + File.extname(filename)
      end
      
      version = options[:b2ec][:productversion] || options[:b2ec][:fileversion]
      if !script.match(/^AppName=/) && options[:b2ec][:productname]
        script.sub!(/^(\[Setup\])(\s+)/i){ "#{$1}\nAppName=#{options[:b2ec][:productname]}#{$2}" }
      end
      if !script.match(/^AppVersion=/) && version
        script.sub!(/^(\[Setup\])(\s+)/i){ "#{$1}\nAppVersion=#{version}#{$2}" }
      end
      if !script.match(/^AppVerName=/) && options[:b2ec][:productname] && version
        script.sub!(/^(\[Setup\])(\s+)/i){ "#{$1}\nAppVerName=#{options[:b2ec][:productname]} #{version}#{$2}" }
      end
      if !script.match(/^AppPublisher=/) && options[:b2ec][:company]
        script.sub!(/^(\[Setup\])(\s+)/i){ "#{$1}\nAppPublisher=#{options[:b2ec][:company]}#{$2}" }
      end
      if !script.match(/^AppCopyright=/) && options[:b2ec][:copyright]
        script.sub!(/^(\[Setup\])(\s+)/i){ "#{$1}\nAppCopyright=#{options[:b2ec][:copyright]}#{$2}" }
      end
      
      script += "\n[Files]\n" unless script.match(/^\[Files\]/)
      dir = File.expand_path(options[:output_dir])
      files_str = ""
      Dir.glob(File.join(dir, "**", "*")).each do |file|
        next unless File.file? file
        dist_dir = to_winpath(File::SEPARATOR + File.dirname(relative_path(file, dir)))
        dist_dir = "" if dist_dir == "\\."
        files_str += "\nSource: \"#{to_winpath(file)}\"; DistDir: \"{app}#{dist_dir}\""
        files_str += "; Flags: isreadme" if File.basename(file).match(/^readme/i)
      end
      script.sub!(/^(\[Files\])(\s*)/i){ "#{$1}#{files_str}#{$2}" }
      
      File.write(filename, script)
      exec = %(#{options[:iscc_path]} "#{filename}")
      nputs_v exec
      options[:quiet] ? `#{exec}` : system(exec)
    end
    
    def run()
      check_options
      dependencies = check_dependencies
      copy_files(dependencies)
      create_batch
      create_datafile          if options[:data_file]
      bat_to_exe_converter unless options[:no_exe]
      upx                      if options[:use_upx]
      create_zipfile           if options[:zipfile]
      inno_setup               if options[:inno_script]
      nputs "Neri Finished."
    end
    
    private
    
    def nputs(str)
      puts "=== #{str}" unless options[:quiet]
    end
    
    def nputs_v(str)
      puts str if options[:verbose]
    end
  end
end
