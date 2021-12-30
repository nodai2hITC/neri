#!/usr/bin/env ruby

require "neri"

module Neri
  @data_files = []

  @options = {
    quiet:   false,

    external_encoding: nil,

    dlls:     [],
    libs:     [],
    gems:     [],
    encoding: "*",

    enable_gems:         false,
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
    b2ec: {
      icon: File.expand_path("#{File.dirname(__FILE__)}/../../share/default.ico"),
      invisible:        nil,
      x64:              nil,
      uac_admin:        nil,
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
  }
  @rubyopt = ENV["RUBYOPT"].to_s
  @args = ""
  @encryption_key = nil

  @use_dxruby       = false
  @use_dxruby_tiled = false
  @use_ayame        = false

  class << self
    attr_reader :options

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
    def basepath  ; File.join(options[:output_dir], basename); end
    def datafile  ; File.join(options[:output_dir], options[:system_dir], options[:datafile]); end

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

  --enable-gems
  --enable-did-you-mean
  --no-chdir
  --pause-last
  --no-pause-last
  --pause-text <text>

  --output-dir <dirname>
  --system-dir <dirname>
  --datafile <filename>
  --encryption-key <key>
  --virtual-directory <string>

  --no-exe
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

    def check_options
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
        when "--external_encoding"
          options[:external_encoding] = ARGV.shift
        when "--dll"
          options[:dlls] += ARGV.shift.split(",").map(&:strip)
        when "--lib"
          options[:libs] += ARGV.shift.split(",").map(&:strip)
        when "--gem"
          options[:gems] += ARGV.shift.split(",").map(&:strip)
        when "--no-enc"
          options[:encoding] = nil
        when "--encoding"
          options[:encoding] = ARGV.shift
        when "--enable-gems"
          options[:enable_gems] = true
        when "--enable-did-you-mean"
          options[:enable_did_you_mean] = true
        when "--no-chdir"
          options[:chdir_first] = false
        when "--chdir-first" # deprecated
          options[:chdir_first] = true
        when "--pause-last"
          options[:pause_last] = true
        when "--no-pause-last"
          options[:pause_last] = false
        when "--pause-text"
          options[:pause_text] = ARGV.shift.encode("utf-8")
          options[:pause_last] = true
        when "--output-dir"
          options[:output_dir] = ARGV.shift.encode("utf-8")
        when "--system-dir"
          options[:system_dir] = ARGV.shift.encode("utf-8")
        when "--datafile"
          options[:datafile] = ARGV.shift.encode("utf-8")
        when "--encryption-key"
          options[:encryption_key] = ARGV.shift.encode("utf-8")
        when "--virtual-directory"
          options[:virtual_directory] = ARGV.shift.encode("utf-8")
        when "--no-exe"
          options[:no_exe] = true
        when "--icon"
          options[:b2ec][:icon] = ARGV.shift.encode("utf-8")
        when "--windows", "--invisible"
          options[:b2ec][:invisible] = true
        when "--console", "--visible"
          options[:b2ec][:invisible] = false
        when "--fileversion"
          options[:b2ec][:fileversion] = ARGV.shift
        when "--productversion"
          options[:b2ec][:productversion] = ARGV.shift
        when "--productname"
          options[:b2ec][:productname] = ARGV.shift.encode("utf-8")
        when "--originalfilename"
          options[:b2ec][:originalfilename] = ARGV.shift.encode("utf-8")
        when "--internalname"
          options[:b2ec][:internalname] = ARGV.shift.encode("utf-8")
        when "--description"
          options[:b2ec][:description] = ARGV.shift.encode("utf-8")
        when "--company"
          options[:b2ec][:company] = ARGV.shift.encode("utf-8")
        when "--trademarks"
          options[:b2ec][:trademarks] = ARGV.shift.encode("utf-8")
        when "--copyright"
          options[:b2ec][:copyright] = ARGV.shift.encode("utf-8")
        when "--privatebuild"
          options[:b2ec][:privatebuild] = ARGV.shift.encode("utf-8")
        when "--specialbuild"
          options[:b2ec][:specialbuild] = ARGV.shift.encode("utf-8")
        when "--comments"
          options[:b2ec][:comments] = ARGV.shift.encode("utf-8")
        when "--"
          break
        when /^(--.+)/
          error "Invalid Option '#{arg}'!"
          output_help
          exit
        else
          @data_files.push(arg.encode("utf-8"))
        end
      end

      if @data_files.empty?
        error "No Script File!"
        output_help
        exit
      end

      @args = ARGV.map { |a| %( "#{a}") }.join("")
      @options[:external_encoding] ||= Encoding.default_external.name
      unless options[:enable_gems] || @rubyopt.index("--disable-gems")
        @rubyopt += " --disable-gems"
      end
      unless options[:enable_did_you_mean] || @rubyopt.index("--disable-did_you_mean")
        @rubyopt += " --disable-did_you_mean"
      end
      @rubyopt.sub!(%r{-r\S+/bundler/setup}, "")
      if @data_files.size > 1 || options[:encryption_key]
        options[:datafile] ||= "#{basename}.dat"
      end
    end

    # check dependencies
    def rb_dependencies
      $LOADED_FEATURES.uniq
    end

    def dll_dependencies
      require "fiddle/import"

      pointer_type = Fiddle::SIZEOF_VOIDP == Fiddle::SIZEOF_LONG_LONG ? 'q*' : 'l!*'
      psapi    = Fiddle.dlopen("psapi.dll")
      kernel32 = Fiddle.dlopen("kernel32.dll")
      enumprocessmodules = Fiddle::Function.new(
        psapi["EnumProcessModules"],
        [Fiddle::TYPE_LONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_LONG,
        Fiddle::Importer.const_get(:CALL_TYPE_TO_ABI)[:stdcall]
      )
      getmodulefilename = Fiddle::Function.new(
        kernel32["GetModuleFileNameW"],
        [Fiddle::TYPE_LONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG],
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
          [process_handle].pack("I").unpack1("i"),
          [module_handle_buffer].pack("p").unpack1(pointer_type),
          [module_handle_buffer.size].pack("I").unpack1("i"),
          [bytes_needed_buffer].pack("p").unpack1(pointer_type)
        )
        bytes_needed = bytes_needed_buffer.unpack1("I")
        break if bytes_needed <= module_handle_buffer.size
      end
      
      handles = module_handle_buffer.unpack("I*")
      dependencies = handles.select { |handle| handle > 0 }.map do |handle|
        str = "\x00\x00" * 256
        modulefilename_length = getmodulefilename.call(
          [handle].pack("I").unpack1("i"),
          [str].pack("p").unpack1(pointer_type),
          [str.size].pack("I").unpack1("i")
        )
        str[0, modulefilename_length * 2].force_encoding("UTF-16LE").encode("UTF-8")
      end

      dependencies.map! { |dep| dep.sub(/^\\\\\?\\/, "") }
      dependencies.map! { |dep| dep.tr(File::ALT_SEPARATOR, File::SEPARATOR) } if File::ALT_SEPARATOR
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
      options[:dlls].each do |dll|
        dependencies += Dir.glob(File.join(bindir, "**", dll))
        dependencies += Dir.glob(File.join(bindir, "**", "#{dll}.*"))
      end
      dependencies.uniq
    end

    def additional_libs_dependencies
      dependencies = []
      options[:libs].each do |lib|
        $LOAD_PATH.each do |path|
          dependencies += Dir.glob(File.join(path, lib))
          dependencies += Dir.glob(File.join(path, "#{lib}.*"))
          dependencies += Dir.glob(File.join(path, lib, "**", "*"))
        end
      end
      dependencies.uniq
    end

    def additional_gems_dependencies
      require "rubygems"
      dependencies = []
      rubygems_dir = File.join(Gem.dir, "gems")
      options[:gems].each do |gem|
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
      return [] unless options[:encoding]

      dependencies = []
      enc_dir = Dir.glob(File.join(RbConfig::CONFIG["archdir"] || RbConfig::TOPDIR, "**", "enc")).first

      options[:encoding].split(",").map(&:strip).each do |enc|
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

    def check_dependencies
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

      if options[:b2ec][:invisible].nil? &&
         (File.extname(scriptfile) == ".rbw" || @use_dxruby)
        options[:b2ec][:invisible] = true
      end
      if options[:pause_last].nil? && !options[:b2ec][:invisible]
        options[:pause_last] = true
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

      size = dependencies.map { |d| File.size(d) }.inject(&:+)
      nputs "#{dependencies.size} files, #{size} bytes dependencies."

      dependencies
    end

    def select_dependencies(dependencies)
      dependencies.select! do |dependency|
        dependency.start_with?(rubydir)
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

      dependencies.uniq
    end

    def copy_files(dependencies)
      nputs "Copying dependencies."
      require "fileutils"
      src_dir  = rubydir
      desc_dir = File.join(options[:output_dir], options[:system_dir], "")

      system_files = dependencies.map do |file|
        [file, file.sub(src_dir, desc_dir)]
      end
      unless options[:enable_gems]
        system_files.each do |_src, desc|
          desc.sub!(%r{/gems(/\d+\.\d+\.\d+/)gems/(.+?)-[^/]+/lib/}, "/vendor_ruby\\1")
        end
      end

      system_files.each do |src, desc|
        FileUtils.makedirs(File.dirname(desc))
        if File.file?(src)
          FileUtils.copy(src, desc)
        end
      end
      FileUtils.copy(scriptfile, desc_dir) unless options[:datafile]
    end

    def create_datafile
      return unless options[:datafile]

      nputs "Creating datafile '#{datafile}'."
      data_files = @data_files.select { |file| File.file? file }
      @data_files.select { |file| File.directory? file }.each do |dir|
        data_files += Dir.glob("#{dir}/**/*").select { |file| File.file? file }
      end
      data_files.uniq! { |file| File.expand_path(file) }

      unless options[:virtual_directory]
        dir_pwd = Dir.pwd.encode(Encoding::UTF_8)
        virtual_directories = Pathname.new(dir_pwd).ascend.to_a.map(&:to_s)
        data_files.each do |file|
          fullpath = File.expand_path(file)
          next if fullpath.start_with?(rubydir) || Pathname.new(file).absolute?
          virtual_directories.shift until fullpath.start_with?(virtual_directories.first)
        end
        options[:virtual_directory] = relative_path(dir_pwd, virtual_directories.first, "/_neri_virtual_directory_/")
        nputs "virtual_directory: #{options[:virtual_directory]}"
      end

      if options[:encryption_key]
        require "digest/sha2"
        @encryption_key = Digest::SHA2.hexdigest(options[:encryption_key])
      end
      Neri.key = @encryption_key || "0" * 64
      File.open(datafile, "wb") do |f|
        pos = 0
        file_informations = data_files.map do |file|
          fullpath = File.expand_path(file)
          filename = if fullpath.start_with?(rubydir)
                       relative_path(fullpath, rubydir, "#{options[:system_dir]}#{File::SEPARATOR}")
                     else
                       file
                     end
          filedata = [filename, File.size(file), pos].join("\t")
          pos += File.size(file)
          pos += BLOCK_LENGTH - pos % BLOCK_LENGTH unless pos % BLOCK_LENGTH == 0
          filedata
        end
        files_str = file_informations.join("\n").encode(Encoding::UTF_8)

        f.write(format("%#{BLOCK_LENGTH}d", files_str.bytesize))
        f.write(xor(files_str))
        data_files.each do |file|
          f.write(xor(File.binread(file)))
        end
      end
    end

    def create_batfile
      nputs "Creating batch_file '#{basepath}.bat'."

      pause_command = ""
      if options[:pause_last]
        pause_command += "echo.\n"
        if options[:pause_text]
          pause_command += "echo #{options[:pause_text]}\n" +
                           "pause > nul"
        else
          pause_command += "pause"
        end
      end
      chdir = options[:chdir_first] ? 'cd /d "%~dp0"' : ""

      File.open("#{basepath}.bat", "w:#{options[:external_encoding]}") do |f|
        f.puts <<-BATCH
@echo off
setlocal
set PATH=%~dp0#{options[:system_dir]}\\#{relative_path(bindir)};%PATH%
set NERI_EXECUTABLE=%~0
#{chdir}
if %~x0 == .exe ( shift )
#{ruby_command(options[:chdir_first] ? '' : '%~dp0')} %1 %2 %3 %4 %5 %6 %7 %8 %9
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
      system_dir = escape_cstr(to_winpath(File.join(options[:system_dir], "")))
      nputs "Creating exe_file '#{exe_file}'."
      File.open(c_file, "w:#{options[:external_encoding]}") do |f|
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
    #{options[:chdir_first] ? 'snprintf(paths, sizeof(paths), "%s%s", drive, dir);chdir(paths);' : ''}
    snprintf(runruby, sizeof(runruby), "#{escape_cstr(ruby_command(options[:chdir_first] ? '' : '%s%s'))} %s %s %s %s %s %s %s %s %s",
        #{options[:chdir_first] ? '' : 'drive, dir,'}
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
        if options[:b2ec][:invisible]
          f.puts %[    CreateProcess(NULL, runruby, NULL, NULL, FALSE, NORMAL_PRIORITY_CLASS | CREATE_NO_WINDOW, NULL, NULL, &si, &pi);]
        else
          f.puts %[    system(runruby);]
        end
        if options[:pause_last]
          f.puts %[    system("echo.");]
          if options[:pause_text]
            f.puts %[    system("echo #{escape_cstr(options[:pause_text])}");]
            f.puts %[    system("pause >nul");]
          else
            f.puts %[    system("pause");]
          end
        end
        f.puts "    return 0;\n}"
      end

      File.open(rc_file, "w:#{options[:external_encoding]}") do |f|
        f.puts <<-RCFILE
#include <winver.h>

1 VERSIONINFO
#{options[:b2ec][:fileversion   ] ? "FILEVERSION     #{escape_cstr(options[:b2ec][:fileversion   ])}" : ""}
#{options[:b2ec][:productversion] ? "PRODUCTVERSION  #{escape_cstr(options[:b2ec][:productversion])}" : ""}
FILETYPE        VFT_APP
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "000004b0"
        BEGIN
            #{options[:b2ec][:fileversion     ] ? 'VALUE "FileVersion",      "' + escape_cstr(options[:b2ec][:fileversion     ]) + '\0"' : ''}
            #{options[:b2ec][:productversion  ] ? 'VALUE "ProductVersion",   "' + escape_cstr(options[:b2ec][:productversion  ]) + '\0"' : ''}
            #{options[:b2ec][:productname     ] ? 'VALUE "ProductName",      "' + escape_cstr(options[:b2ec][:productname     ]) + '\0"' : ''}
            #{options[:b2ec][:originalfilename] ? 'VALUE "OriginalFileName", "' + escape_cstr(options[:b2ec][:originalfilename]) + '\0"' : ''}
            #{options[:b2ec][:internalname    ] ? 'VALUE "InternalName",     "' + escape_cstr(options[:b2ec][:internalname    ]) + '\0"' : ''}
            #{options[:b2ec][:description     ] ? 'VALUE "FileDescription",  "' + escape_cstr(options[:b2ec][:description     ]) + '\0"' : ''}
            #{options[:b2ec][:company         ] ? 'VALUE "CompanyName",      "' + escape_cstr(options[:b2ec][:company         ]) + '\0"' : ''}
            #{options[:b2ec][:trademarks      ] ? 'VALUE "LegalTrademarks",  "' + escape_cstr(options[:b2ec][:trademarks      ]) + '\0"' : ''}
            #{options[:b2ec][:copyright       ] ? 'VALUE "LegalCopyright",   "' + escape_cstr(options[:b2ec][:copyright       ]) + '\0"' : ''}
            #{options[:b2ec][:privatebuild    ] ? 'VALUE "PrivateBuild",     "' + escape_cstr(options[:b2ec][:privatebuild    ]) + '\0"' : ''}
            #{options[:b2ec][:specialbuild    ] ? 'VALUE "SpecialBuild",     "' + escape_cstr(options[:b2ec][:specialbuild    ]) + '\0"' : ''}
            #{options[:b2ec][:comments        ] ? 'VALUE "Comments",         "' + escape_cstr(options[:b2ec][:comments        ]) + '\0"' : ''}
        END
    END

    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x0, 0x4b0
    END
END

2 ICON "#{escape_cstr(options[:b2ec][:icon])}"
        RCFILE
      end
      nsystem(%(windres -o "#{o_file}" "#{rc_file}"))
      nsystem(%(gcc#{options[:b2ec][:invisible] ? ' -mwindows' : ''} -o "#{exe_file}" "#{c_file}" "#{o_file}"))
      nsystem(%(strip "#{exe_file}"))
      File.delete(c_file, rc_file, o_file)
    end

    def ruby_command(path)
      system_dir = "#{path}#{File.join(options[:system_dir], '')}"
      ruby_code = ""
      ruby_code = "Neri.key='#{@encryption_key}';" if @encryption_key
      if options[:datafile]
        ruby_code += "Neri.datafile='#{system_dir}' + #{unpack_filename(options[:datafile])};"
        if options[:virtual_directory]
          ruby_code += "Neri.virtual_directory=#{unpack_filename(options[:virtual_directory])};"
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
      options[:no_exe] ? create_batfile : create_exefile
      nputs "Neri Finished."
    end

    private

    def nputs(str)
      puts "=== #{str}" unless options[:quiet]
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
      command = str.encode(options[:external_encoding])
      system(command + (options[:quiet] ? " >nul 2>&1" : ""))
    end
  end
end
