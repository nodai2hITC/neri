#!/usr/bin/env ruby

require "neri"

module NeriBuild
  @data_files = []

  @options = {
    quiet:   false,

    external_encoding: nil,

    dlls:     [],
    libs:     [],
    gems:     [],
    encoding: "*",

    enable_gems:         true,
    enable_did_you_mean: false,
    chdir_first:         true,
    pause_last:          nil,
    pause_text:          nil,

    output_dir: "./",
    system_dir: "system",

    datafile:       nil,
    encryption_key: nil,
    virtual_directory: nil,

    no_exe: false,
    icon: File.expand_path("#{File.dirname(__FILE__)}/../../share/default.ico"),
    invisible:        nil,
    fileversion:      nil,
    productversion:   nil,
    productname:      nil,
    originalfilename: nil,
    internalname:     nil,
    description:      nil,
    company:          nil,
    trademarks:       nil,
    copyright:        nil,
    privatebuild:     nil,
    specialbuild:     nil,
    comments:         nil
  }
  @rubyopt = ENV["RUBYOPT"].to_s.encode(Encoding::UTF_8)
  @args = ""
  @encryption_key = nil

  @use_dxruby       = false
  @use_dxruby_tiled = false
  @use_ayame        = false

  @require_paths = {}

  class << self
    def gemspec_path(file)
      return nil unless file.match?(%r{/gems/\d+\.\d+\.\d+/gems/(.+?-[^/]+)/})

      file.sub(%r{(/gems/\d+\.\d+\.\d+)/gems/(.+?-[^/]+)/.+\z}) do
        "#{Regexp.last_match(1)}/specifications/#{Regexp.last_match(2)}.gemspec"
      end
    end

    def gem_require_paths(file)
      path = gemspec_path(file)
      return nil unless path
      return @require_paths[path] if @require_paths.key?(path)

      @require_paths[path] = ["lib/"]
      if File.exist?(path)
        gemspec = File.binread(path)
        if gemspec.match(/\.require_paths\s*=\s*\[([^\]]+)\]/)
          @require_paths[path] = Regexp.last_match(1).scan(/['"]([^'"]+)['"]/).flatten.map do |p|
            "#{p.delete_suffix('/')}/"
          end
        end
      end
      @require_paths[path]
    end

    def relative_path(path, basedir = rubydir, prepath = "")
      basedir.concat(File::SEPARATOR) unless basedir.end_with?(File::SEPARATOR)
      path.start_with?(basedir) ? path.sub(basedir, prepath) : path
    end

    def to_winpath(path)
      File::ALT_SEPARATOR ? path.tr(File::SEPARATOR, File::ALT_SEPARATOR) : path
    end

    def bindir    ; RbConfig::CONFIG["bindir"] || File.join(rubydir, "bin"); end
    def rubydir   ; File.join(RbConfig::TOPDIR, ""); end
    def rubyexe   ; RbConfig.ruby; end
    def scriptfile; @data_files.first; end
    def basename  ; File.basename(scriptfile, ".*"); end
    def basepath  ; File.join(@options[:output_dir], basename); end
    def datafile  ; File.join(@options[:output_dir], @options[:system_dir], @options[:datafile]); end

    # --help
    def output_help
      puts <<-HELP_MESSAGE
usage: neri [options] script.rb (other_files...) -- script_arguments

options:
  --help or -h
  --version or -v
  --quiet

  --external-encoding <encoding>

  --dll <dll1>,<dll2>,...
  --lib <lib1>,<lib2>,...
  --gem <gem1>,<gem2>,...

  --no-enc
  --encoding <enc1>,<enc2>,...

  --enable-gems / --disable-gems
  --enable-did-you-mean / --disable-did-you-mean
  --no-chdir
  --pause-last
  --no-pause-last
  --pause-text <text>

  --output-dir <dirname>
  --system-dir <dirname>
  --datafile <filename>
  --encryption-key <key>
  --virtual-directory <string>

  --no-exe or --bat
  --icon <iconfile>
  --windows or --invisible
  --console or --visible
  --fileversion <string>     # ex) 1,2,3,4
  --productversion <string>  # ex) 1,2,3,4
  --productname <string>
  --originalfilename <string>
  --internalname <string>
  --description <string>
  --company <string>
  --trademarks <string>
  --copyright <string>
  --privatebuild <string>
  --specialbuild <string>
  --comments <string>
      HELP_MESSAGE
    end

    # --version
    def output_version
      puts "Neri #{Neri::VERSION}"
    end

    def load_options(argv)
      until argv.empty?
        arg = argv.shift
        case arg
        when "--help", "-h"
          output_help
          exit
        when "--version", "-v"
          output_version
          exit
        when "--quiet", "-q"
          @options[:quiet] = true
        when "--external-encoding"
          @options[:external_encoding] = argv.shift
        when "--dll"
          @options[:dlls] += argv.shift.split(",").map(&:strip)
        when "--lib"
          @options[:libs] += argv.shift.split(",").map(&:strip)
        when "--gem"
          @options[:gems] += argv.shift.split(",").map(&:strip)
        when "--no-enc"
          @options[:encoding] = nil
        when "--encoding"
          @options[:encoding] = argv.shift
        when "--enable-gems"
          @options[:enable_gems] = true
        when "--disale-gems"
          @options[:enable_gems] = false
        when "--enable-did-you-mean"
          @options[:enable_did_you_mean] = true
        when "--disale-did-you-mean"
          @options[:enable_did_you_mean] = false
        when "--no-chdir"
          @options[:chdir_first] = false
        when "--chdir-first" # deprecated
          @options[:chdir_first] = true
        when "--pause-last"
          @options[:pause_last] = true
        when "--no-pause-last"
          @options[:pause_last] = false
        when "--pause-text"
          @options[:pause_text] = argv.shift
          @options[:pause_last] = true
        when "--output-dir"
          @options[:output_dir] = argv.shift
        when "--system-dir"
          @options[:system_dir] = argv.shift
        when "--datafile"
          @options[:datafile] = argv.shift
        when "--encryption-key"
          @options[:encryption_key] = argv.shift
        when "--virtual-directory"
          @options[:virtual_directory] = argv.shift
        when "--no-exe", "--bat"
          @options[:no_exe] = true
        when "--icon"
          @options[:icon] = argv.shift
        when "--windows", "--invisible"
          @options[:invisible] = true
        when "--console", "--visible"
          @options[:invisible] = false
        when "--fileversion"
          @options[:fileversion] = argv.shift
        when "--productversion"
          @options[:productversion] = argv.shift
        when "--productname"
          @options[:productname] = argv.shift
        when "--originalfilename"
          @options[:originalfilename] = argv.shift
        when "--internalname"
          @options[:internalname] = argv.shift
        when "--description"
          @options[:description] = argv.shift
        when "--company"
          @options[:company] = argv.shift
        when "--trademarks"
          @options[:trademarks] = argv.shift
        when "--copyright"
          @options[:copyright] = argv.shift
        when "--privatebuild"
          @options[:privatebuild] = argv.shift
        when "--specialbuild"
          @options[:specialbuild] = argv.shift
        when "--comments"
          @options[:comments] = argv.shift
        when "--"
          break
        when /^(--.+)/
          error "Invalid Option '#{arg}'!"
          output_help
          exit
        else
          if File.exist?(arg)
            @data_files.push(arg)
          else
            error "File '#{arg}' not found!"
            exit
          end
        end
      end

      @args += argv.map { |a| %( "#{a}") }.join("")
    end

    def load_options_from_file(file)
      fullpath = File.expand_path(file)
      return unless File.exist?(fullpath)

      argv = File.read(fullpath, encoding: Encoding::UTF_8).lines.flat_map do |line|
        line.strip.split(" ", 2)
      end
      load_options(argv)
    end

    def check_options
      load_options_from_file("~/neri.config")
      load_options_from_file("./neri.config")
      tmp_data_files = @data_files
      @data_files = []
      load_options(ARGV.map { |arg| arg.encode(Encoding::UTF_8) })
      until ARGV.empty?
        break if ARGV.shift == "--"
      end
      @data_files += tmp_data_files
      if @data_files.empty?
        error "No Script File!"
        output_help
        exit
      end

      @options[:external_encoding] ||= Encoding.default_external.name
      unless @options[:enable_gems] || @rubyopt.index("--disable-gems")
        @rubyopt += " --disable-gems"
      end
      unless @options[:enable_did_you_mean] || @rubyopt.index("--disable-did_you_mean")
        @rubyopt += " --disable-did_you_mean"
      end
      @rubyopt.sub!(%r{-r\S+/bundler/setup}, "")
      if @data_files.size > 1 || @options[:encryption_key]
        @options[:datafile] ||= "#{basename}.dat"
      end
    end

    def run_script
      nputs "Running script '#{scriptfile}' to check dependencies."
      begin
        load File.expand_path(scriptfile)
      rescue SystemExit, Interrupt
      end
      nputs "Script '#{scriptfile}' end."

      if defined? DXRuby
        require "neri/dxruby"
        @use_dxruby = true
      end
      if defined? DXRuby::Tiled
        require "neri/dxruby_tiled"
        @use_dxruby_tiled = true
      end
      if defined? Ayame
        require "neri/ayame"
        @use_ayame = true
      end

      if @options[:invisible].nil?
        if File.extname(scriptfile) == ".rbw" ||
           defined?(DXRuby) ||
           defined?(Gosu) ||
           defined?(LibUI)
          @options[:invisible] = true
        end
      end
      if @options[:pause_last].nil? && !@options[:invisible]
        @options[:pause_last] = true
      end
    end

    # check dependencies
    def rb_dependencies
      $LOADED_FEATURES.uniq
    end

    def dll_dependencies
      require "fiddle/import"

      psapi    = Fiddle.dlopen("psapi.dll")
      kernel32 = Fiddle.dlopen("kernel32.dll")
      enumprocessmodules = Fiddle::Function.new(
        psapi["EnumProcessModules"],
        [Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_LONG,
        Fiddle::Importer.const_get(:CALL_TYPE_TO_ABI)[:stdcall]
      )
      getmodulefilename = Fiddle::Function.new(
        kernel32["GetModuleFileNameW"],
        [Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG],
        Fiddle::TYPE_LONG,
        Fiddle::Importer.const_get(:CALL_TYPE_TO_ABI)[:stdcall]
      )
      getcurrentprocess = Fiddle::Function.new(
        kernel32["GetCurrentProcess"],
        [],
        Fiddle::TYPE_LONG,
        Fiddle::Importer.const_get(:CALL_TYPE_TO_ABI)[:stdcall]
      )

      bytes_needed = 4 * 32
      module_handle_buffer = nil
      process_handle = getcurrentprocess.call
      loop do
        module_handle_buffer = "\x00" * bytes_needed
        bytes_needed_buffer = [0].pack("I")
        enumprocessmodules.call(
          process_handle,
          module_handle_buffer,
          module_handle_buffer.size,
          bytes_needed_buffer
        )
        bytes_needed = bytes_needed_buffer.unpack1("I")
        break if bytes_needed <= module_handle_buffer.size
      end

      handles = module_handle_buffer.unpack("I*")
      dependencies = handles.select { |handle| handle > 0 }.map do |handle|
        str = "\x00\x00" * 256
        modulefilename_length = getmodulefilename.call(handle, str, str.size)
        str[0, modulefilename_length * 2].force_encoding("UTF-16LE").encode("UTF-8")
      end

      dependencies.map! { |dep| dep.sub(/^\\\\\?\\/, "") }
      dependencies.map! { |dep| dep.tr("\\", "/") }
      dependencies.delete(rubyexe)

      dependencies.uniq
    end

    def ruby_dependencies
      dependencies = Dir.glob(File.join(bindir, "**", "*.manifest"))
      dependencies.push(rubyexe)
      dependencies.uniq
    end

    def additional_dlls_dependencies
      dependencies = []
      @options[:dlls].push("*.dll") if RbConfig::CONFIG["arch"].include?("x64")
      @options[:dlls].each do |dll|
        dependencies += Dir.glob(File.join(bindir, "**", dll))
        dependencies += Dir.glob(File.join(bindir, "**", "#{dll}.*"))
      end
      dependencies.uniq
    end

    def additional_libs_dependencies
      dependencies = []
      @options[:libs].each do |lib|
        $LOAD_PATH.each do |path|
          dependencies += Dir.glob(File.join(path, lib))
          dependencies += Dir.glob(File.join(path, "#{lib}.*"))
          dependencies += Dir.glob(File.join(path, lib, "**", "*"))
        end
      end
      dependencies.uniq
    end

    def additional_gems_dependencies
      dependencies = []
      rubygems_dir = File.join(Gem.dir, "gems")
      @options[:gems].each do |gem|
        gem.sub!(/:(.+)/, "")
        targets = Regexp.last_match(1).to_s.split("|")
        targets.push("lib/**/*")
        gem += "-*" unless gem.match("-")
        gemdir = Dir.glob(File.join(rubygems_dir, gem)).max
        next unless gemdir

        targets.each do |target|
          dependencies += Dir.glob(File.join(gemdir, target))
        end
      end
      dependencies.uniq
    end

    def encoding_dependencies
      return [] unless @options[:encoding]

      dependencies = []
      enc_dir = Dir.glob(File.join(RbConfig::CONFIG["archdir"] || RbConfig::TOPDIR, "**", "enc")).first

      @options[:encoding].split(",").map(&:strip).each do |enc|
        case enc
        when "ja"
          %w[windows_31j.so japanese_sjis.so encdb.so].each do |enc_name|
            dependencies += Dir.glob(File.join(enc_dir, "**", enc_name))
          end
        else
          dependencies += Dir.glob(File.join(enc_dir, "**", enc))
          dependencies += Dir.glob(File.join(enc_dir, "**", "#{enc}.*"))
        end
      end

      dependencies.uniq
    end

    def select_dependencies(dependencies)
      dependencies.select! do |dependency|
        dependency.start_with?(rubydir)
      end

      @data_files.each do |file|
        dependencies.delete(File.expand_path(file))
      end

      unless @options[:enable_gems]
        dependencies.delete_if do |dependency|
          File.basename(dependency) == "rubygems.rb" ||
            dependency.split(File::SEPARATOR).index("rubygems")
        end
      end
      unless @options[:enable_did_you_mean]
        dependencies.delete_if do |dependency|
          File.basename(dependency) == "did_you_mean.rb" ||
            dependency.split(File::SEPARATOR).index("did_you_mean")
        end
      end

      dependencies.uniq
    end

    def gemspec_dependencies(dependencies)
      default_gemspec_dir = Gem.default_specifications_dir.encode(Encoding::UTF_8)
      gemspecs = Dir.glob("#{default_gemspec_dir}/**/*")
      gemspecs += dependencies.map { |depend| gemspec_path(depend) }
      gemspecs.compact.uniq
    end

    def check_dependencies
      run_script

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
      dependencies += gemspec_dependencies(dependencies) if @options[:enable_gems]
      if dependencies.find { |dep| dep.end_with?("/net/https.rb") }
        dependencies.push("#{rubydir}ssl/cert.pem")
      end

      size = dependencies.map { |d| File.size(d) }.inject(&:+)
      nputs "#{dependencies.size} files, #{size} bytes dependencies."

      dependencies
    end

    def copy_files(dependencies)
      nputs "Copying dependencies."
      require "fileutils"
      src_dir  = rubydir
      desc_dir = File.join(@options[:output_dir], @options[:system_dir], "")

      system_files = dependencies.map do |file|
        [file, file.sub(src_dir, desc_dir)]
      end
      unless @options[:enable_gems]
        system_files.each do |src, desc|
          paths = gem_require_paths(src)
          next unless paths

          desc.sub!(%r{/gems/(\d+\.\d+\.\d+)/gems/.+?-[^/]+/(.+)\z}) do
            version, file = Regexp.last_match(1), Regexp.last_match(2)
            paths.each do |path|
              file = file.sub(path, "#{version}/") if file.start_with?(path)
            end
            "/vendor_ruby/#{file}"
          end
        end
      end

      system_files.each do |src, desc|
        FileUtils.makedirs(File.dirname(desc))
        FileUtils.copy(src, desc) if File.file?(src)
      end
      FileUtils.copy(scriptfile, desc_dir) unless @options[:datafile]
    end

    def create_datafile
      return unless @options[:datafile]

      nputs "Creating datafile '#{datafile}'."
      data_files = @data_files.select { |file| File.file? file }
      @data_files.select { |file| File.directory? file }.each do |dir|
        data_files += Dir.glob("#{dir}/**/*").select { |file| File.file? file }
      end
      data_files.uniq! { |file| File.expand_path(file) }

      unless @options[:virtual_directory]
        dir_pwd = Dir.pwd.encode(Encoding::UTF_8)
        virtual_directories = Pathname.new(dir_pwd).ascend.to_a.map(&:to_s)
        data_files.each do |file|
          fullpath = File.expand_path(file)
          next if fullpath.start_with?(rubydir) || Pathname.new(file).absolute?

          virtual_directories.shift until fullpath.start_with?(virtual_directories.first)
        end
        @options[:virtual_directory] = relative_path(dir_pwd, virtual_directories.first, "/_neri_virtual_directory_/")
        nputs "virtual_directory: #{@options[:virtual_directory]}"
      end

      if @options[:encryption_key]
        require "digest/sha2"
        @encryption_key = Digest::SHA2.hexdigest(@options[:encryption_key])
      end
      Neri.key = @encryption_key || "0" * 64
      File.open(datafile, "wb") do |f|
        pos = 0
        file_informations = data_files.map do |file|
          fullpath = File.expand_path(file)
          filename = if fullpath.start_with?(rubydir)
                       relative_path(fullpath, rubydir, "#{@options[:system_dir]}#{File::SEPARATOR}")
                     else
                       file
                     end
          filedata = [filename, File.size(file), pos].join("\t")
          pos += File.size(file)
          pos += Neri::BLOCK_LENGTH - pos % Neri::BLOCK_LENGTH unless pos % Neri::BLOCK_LENGTH == 0
          filedata
        end
        files_str = file_informations.join("\n").encode(Encoding::UTF_8)

        f.write(format("%#{Neri::BLOCK_LENGTH}d", files_str.bytesize))
        f.write(xor(files_str))
        data_files.each do |file|
          f.write(xor(File.binread(file)))
        end
      end
    end

    def create_batfile
      nputs "Creating batch_file '#{basepath}.bat'."

      pause_command = ""
      if @options[:pause_last]
        pause_command += "echo.\n"
        pause_command +=
          if @options[:pause_text]
            "echo #{@options[:pause_text]}\npause > nul"
          else
            "pause"
          end
      end
      chdir = @options[:chdir_first] ? 'cd /d "%~dp0"' : ""

      File.open("#{basepath}.bat", "w:#{@options[:external_encoding]}") do |f|
        f.puts <<-BATCH
@echo off
setlocal
set PATH=%~dp0#{@options[:system_dir]}\\#{relative_path(bindir)};%PATH%
set NERI_EXECUTABLE=%~0
#{chdir}
if %~x0 == .exe ( shift )
#{ruby_command(@options[:chdir_first] ? '' : '%~dp0')} %1 %2 %3 %4 %5 %6 %7 %8 %9
#{pause_command}
endlocal
        BATCH
      end
    end

    def create_exefile
      unless system("gcc --version >nul 2>&1 && windres --version >nul 2>&1")
        error "gcc or windres not found !"
        create_batfile
        return
      end

      exe_file = to_winpath("#{basepath}.exe"   )
      c_file   = to_winpath("#{basepath}_tmp.c" )
      o_file   = to_winpath("#{basepath}_tmp.o" )
      rc_file  = to_winpath("#{basepath}_tmp.rc")
      system_dir = escape_cstr(to_winpath(File.join(@options[:system_dir], "")))
      nputs "Creating exe_file '#{exe_file}'."
      File.open(c_file, "w:#{@options[:external_encoding]}") do |f|
        f.puts <<-CFILE
#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    char exepath[_MAX_PATH  *  2 + 1],
         drive  [_MAX_DRIVE      + 1],
         dir    [_MAX_DIR   *  2 + 1],
         fname  [_MAX_FNAME *  2 + 1],
         ext    [_MAX_EXT   *  2 + 1],
         paths  [_MAX_PATH  * 32 + 1],
         runruby[_MAX_PATH  * 32 + 1];
    PROCESS_INFORMATION pi;
    STARTUPINFO si;
    ZeroMemory(&si, sizeof(STARTUPINFO));

    if(GetModuleFileName(NULL, exepath, MAX_PATH * 2) != 0){
        _splitpath_s(exepath, drive, _MAX_DRIVE, dir, _MAX_DIR * 2, fname, _MAX_FNAME * 2, ext, _MAX_EXT * 2);
    } else {
        exit(EXIT_FAILURE);
    }
    snprintf(paths, sizeof(paths), "NERI_EXECUTABLE=%s", exepath);
    putenv(paths);
    snprintf(paths, sizeof(paths), "PATH=%s%s#{system_dir}bin;%s", drive, dir, getenv("PATH"));
    putenv(paths);
    #{@options[:chdir_first] ? 'snprintf(paths, sizeof(paths), "%s%s", drive, dir);chdir(paths);' : ''}
    snprintf(runruby, sizeof(runruby), "#{escape_cstr(ruby_command(@options[:chdir_first] ? '' : '%s%s'))} %s %s %s %s %s %s %s %s %s",
        #{@options[:chdir_first] ? '' : 'drive, dir,'}
        argc > 1 ? argv[1] : "",
        argc > 2 ? argv[2] : "",
        argc > 3 ? argv[3] : "",
        argc > 4 ? argv[4] : "",
        argc > 5 ? argv[5] : "",
        argc > 6 ? argv[6] : "",
        argc > 7 ? argv[7] : "",
        argc > 8 ? argv[8] : "",
        argc > 9 ? argv[9] : ""
        );
        CFILE
        if @options[:invisible]
          f.puts %[    CreateProcess(NULL, runruby, NULL, NULL, FALSE, NORMAL_PRIORITY_CLASS | CREATE_NO_WINDOW, NULL, NULL, &si, &pi);]
        else
          f.puts %[    system(runruby);]
        end
        if @options[:pause_last]
          f.puts %[    system("echo.");]
          if @options[:pause_text]
            f.puts %[    system("echo #{escape_cstr(@options[:pause_text])}");]
            f.puts %[    system("pause >nul");]
          else
            f.puts %[    system("pause");]
          end
        end
        f.puts "    return 0;\n}"
      end

      File.open(rc_file, "w:#{@options[:external_encoding]}") do |f|
        f.puts <<-RCFILE
#include <winver.h>

1 VERSIONINFO
#{@options[:fileversion   ] ? "FILEVERSION     #{escape_cstr(@options[:fileversion   ])}" : ''}
#{@options[:productversion] ? "PRODUCTVERSION  #{escape_cstr(@options[:productversion])}" : ''}
FILETYPE        VFT_APP
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "000004b0"
        BEGIN
            #{@options[:fileversion     ] ? 'VALUE "FileVersion",      "' + escape_cstr(@options[:fileversion     ]) + '\0"' : ''}
            #{@options[:productversion  ] ? 'VALUE "ProductVersion",   "' + escape_cstr(@options[:productversion  ]) + '\0"' : ''}
            #{@options[:productname     ] ? 'VALUE "ProductName",      "' + escape_cstr(@options[:productname     ]) + '\0"' : ''}
            #{@options[:originalfilename] ? 'VALUE "OriginalFileName", "' + escape_cstr(@options[:originalfilename]) + '\0"' : ''}
            #{@options[:internalname    ] ? 'VALUE "InternalName",     "' + escape_cstr(@options[:internalname    ]) + '\0"' : ''}
            #{@options[:description     ] ? 'VALUE "FileDescription",  "' + escape_cstr(@options[:description     ]) + '\0"' : ''}
            #{@options[:company         ] ? 'VALUE "CompanyName",      "' + escape_cstr(@options[:company         ]) + '\0"' : ''}
            #{@options[:trademarks      ] ? 'VALUE "LegalTrademarks",  "' + escape_cstr(@options[:trademarks      ]) + '\0"' : ''}
            #{@options[:copyright       ] ? 'VALUE "LegalCopyright",   "' + escape_cstr(@options[:copyright       ]) + '\0"' : ''}
            #{@options[:privatebuild    ] ? 'VALUE "PrivateBuild",     "' + escape_cstr(@options[:privatebuild    ]) + '\0"' : ''}
            #{@options[:specialbuild    ] ? 'VALUE "SpecialBuild",     "' + escape_cstr(@options[:specialbuild    ]) + '\0"' : ''}
            #{@options[:comments        ] ? 'VALUE "Comments",         "' + escape_cstr(@options[:comments        ]) + '\0"' : ''}
        END
    END

    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x0, 0x4b0
    END
END

2 ICON "#{escape_cstr(@options[:icon])}"
        RCFILE
      end
      nsystem(%(windres -o "#{o_file}" "#{rc_file}"))
      nsystem(%(gcc#{@options[:invisible] ? ' -mwindows' : ''} -o "#{exe_file}" "#{c_file}" "#{o_file}"))
      nsystem(%(strip "#{exe_file}"))
      File.delete(c_file, rc_file, o_file)
    end

    def ruby_command(path)
      system_dir = "#{path}#{File.join(@options[:system_dir], '')}"
      ruby_code = ""
      ruby_code = "Neri.key='#{@encryption_key}';" if @encryption_key
      if @options[:datafile]
        ruby_code += "Neri.datafile='#{system_dir}' + #{unpack_filename(@options[:datafile])};"
        if @options[:virtual_directory]
          ruby_code += "Neri.virtual_directory=#{unpack_filename(@options[:virtual_directory])};"
        end
        ruby_code += "load #{unpack_filename(File.basename(scriptfile))}"
      else
        ruby_code += "load File.expand_path('#{system_dir}' + #{unpack_filename(scriptfile)})"
      end

      r  = " -rneri"
      r += " -rneri/dxruby"       if @use_dxruby
      r += " -rneri/dxruby_tiled" if @use_dxruby_tiled
      r += " -rneri/ayame"        if @use_ayame

      ruby = to_winpath(relative_path(rubyexe, bindir))
      %(#{ruby}#{r} #{@rubyopt} -e "# coding:utf-8" -e "#{ruby_code}" #{@args})
    end

    def run
      check_options
      dependencies = check_dependencies
      copy_files(dependencies)
      create_datafile
      @options[:no_exe] ? create_batfile : create_exefile
      nputs "Neri Finished."
    end

    private

    def xor(str)
      Neri.__send__(:xor, str)
    end

    def nputs(str)
      puts "=== #{str}" unless @options[:quiet]
    end

    def error(str)
      puts "\e[31m#{str}\e[0m"
    end

    def unpack_filename(filename)
      "[#{filename.unpack('U*').map(&:to_s).join(',')}].pack('U*')"
    end

    def escape_cstr(str)
      str.gsub("\\") { "\\\\" }.gsub('"') { '\\"' }.gsub("'") { "\\'" }
    end

    def nsystem(str)
      command = str.encode(@options[:external_encoding])
      system(command + (@options[:quiet] ? " >nul 2>&1" : ""))
    end
  end
end
