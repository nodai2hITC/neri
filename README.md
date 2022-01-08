# Neri

[日本語説明](https://github.com/nodai2hITC/neri/blob/master/README.ja.md)

Neri is a packaging system for distributing Ruby scripts on Windows without Ruby installation.

There is a similar gem [OCRA](https://github.com/larsch/ocra), but Neri has the following differences.

- Advantages compared to OCRA
  - Faster startup due to no expansion.
  - When you want to create multiple executable files, OCRA generates multiple large executable files, but Neri can share system files, so the overall size is not large.
  - OCRA has the problem that it cannot be run in environments with user names containing Non-Ascii characters, but Neri does not have this problem.
- Disadvantages compared to OCRA
  - Basically, Neri can be used only in the environment where Ruby is installed by [Ruby Installer 2](https://rubyinstaller.org/) With Devkit. (Also, you need to run `ridk enable` to pass it before use.)

## Installation

    $ gem install neri

It is also possible to use Neri with bundler, but it is not recommended because it increases the number of files to be included.

## How to use

First, you need to run `ridk enable` to set pass to the development environment.

    $ neri [options] script.rb (other_files...) -- script_arguments

In the example above, Neri run "script.rb" once to check for dependency files, and then copy the files you need as dependency files to the output folder.
And then create the executable file.

If you copy the entire output folder, you can run the script even in an environment without Ruby.

### options:

#### Basic options

<dl>
  <dt>--help or -h</dt>
  <dd>Show help.</dd>
  <dt>--version or -v</dt>
  <dd>Show version of Neri.</dd>
  <dt>--quiet</dt>
  <dd>It will no longer display the progress during execution.</dd>
</dl>

#### Add dependent files

Neri will automatically copy the files that it thinks are necessary for execution to the output folder as dependent files.
However, there may be cases where that determination does not work and you do not have enough files for execution.
In such cases, you need to add the dependency files manually with these options.

(or copy the necessary files directly to the output destination manually.)

<dl>
  <dt>--dll &lt;dll1&gt;,&lt;dll2&gt;,...</dt>
  <dd>Add the specified dll file in the bin folder to the dependency files.</dd>
  <dt>--lib &lt;lib1&gt;,&lt;lib2&gt;,...</dt>
  <dd>Add the specified file in $LOAD_PATH to the dependency files.</dd>
  <dt>--gem &lt;gem1&gt;,&lt;gem2&gt;,...</dt>
  <dd>Adds the files of the specified gem to the dependency files.
  By default, it will add the set of files in the lib folder of the gem to the dependency files. (You can use `--gem gemname:dir1|dir2` to add files other than the lib folder.)
  Currently, the dependencies between gems are not checked, so you need to add all necessary gems manually.</dd>
</dl>

#### Encoding

By default, Neri adds all encoding files in the enc folder to the dependency files, but this increases the overall file size.

By specifying the encoding files to be copied with these options, you can minimize the amount of data.

<dl>
  <dt>--no-enc</dt>
  <dd>Do not add Encoding files to the dependency files except for the ones you actually used.</dd>
  <dt>--encoding &lt;enc1&gt;,&lt;enc2&gt;,...</dt>
  <dd>Manually specify the encoding file to be added.</dd>
</dl>

↓ Example: Add only "windows_31j.so" and "japanese_sjis.so" to the dependency files.

    $ neri --encoding windows_31j.so,japanese_sjis.so script.rb

#### Setting

<dl>
  <dt>--enable-gems</dt>
  <dd>Use rubygems. If you don't use this option, the necessary gem files will be copied to the vendor_ruby folder, so that you can run without rubygems.</dd>
  <dt>--enable-did-you-mean</dt>
  <dd>use did_you_mean</dd>
  <dt>--no-chdir</dt>
  <dd>By default, executables created by Neri will set the current folder to the same folder as the executable at runtime. With this option, the current folder will not be changed. (Please note that this option may not work well under Non-Ascii name folders.)</dd>
  <dt>--pause-last</dt>
  <dt>--no-pause-last</dt>
  <dd>Set whether or not to include pause at the end of the execution. If omitted, it will be set to "on" for console applications (see below) and "off" for window applications.</dd>
  <dt>--pause-text &lt;text&gt;</dt>
  <dd>Sets the display contents when pause is applied.</dd>
</dl>

#### Output

<dl>
  <dt>--output-dir &lt;dirname&gt;</dt>
  <dd>Specifies the output folder name. If omitted, it will be the current folder (. /).</dd>
  <dt>--system-dir &lt;dirname&gt;</dt>
  <dd>Specify the name of the system folder where ruby and other files will be copied. The default is "system".</dd>
  <dt>--datafile &lt;filename&gt;</dt>
  <dd>Specify the data file name.If omitted, the name of the data file will be the file name of the executed script file with the extension changed to ".dat".
  If you omit this option and there is no other file to put into the data file, the data file will not be created and the executed script file will be copied directly into the system folder.</dd>
  <dt>--encryption-key &lt;key&gt;</dt>
  <dd>Set the encryption key for the data file. If omitted, no encryption will be performed.
  Since encryption is simple, it cannot be used for important data that must not be decrypted.</dd>
  <dt>--virtual-directory &lt;dirname&gt;</dt>
  <dd>When reading a file from a data file, Neri will first search for the file based on the current folder at runtime, and if not found, it will search for the file based on this virtual-directory.
  If omitted, Neri will automatically generate the appropriate virtual path.</dd>
</dl>

#### Creating an executable file

<dl>
  <dt>--no-exe or --bat</dt>
  <dd>Do not create an exe file, but create a bat file.</dd>
  <dt>--icon &lt;iconfile&gt;</dt>
  <dd>Set the icon.</dd>
  <dt>--windows or --invisible</dt>
  <dt>--console or --visible</dt>
  <dd>Set whether you want to use a windowed app or a console app.
  If it is a windowed app, the command prompt will not open.
  If omitted, it will be a windowed app if the executed script file extension is ".rbw", or if [DXRuby](http://dxruby.osdn.jp/), [Gosu](https://www.libgosu.org/ruby.html), or [LibUI](https://github.com/kojix2/libui) is used.
  Otherwise, it will be a console app.</dd>
  <dt>--fileversion &lt;version&gt;</dt>
  <dt>--productversion &lt;version&gt;</dt>
  <dd>Set the file version and product version.
  Set &lt;version&gt; to four numbers separated by commas, such as 1,2,3,4.</dd>
  <dt>--productname &lt;string&gt;</dt>
  <dt>--internalname &lt;string&gt;</dt>
  <dt>--description &lt;string&gt;</dt>
  <dt>--company &lt;string&gt;</dt>
  <dt>--trademarks &lt;string&gt;</dt>
  <dt>--copyright &lt;string&gt;</dt>
  <dd>Set the product name, internal name, file description, company name, trademarks, and copyrights.</dd>
  <dt>--privatebuild &lt;string&gt;</dt>
  <dt>--specialbuild &lt;string&gt;</dt>
  <dt>--comments &lt;string&gt;</dt>
  <dd>Set comments, etc.</dd>
</dl>

### Configuration by neri.config file

If you create a file named `neri.config` in your HOME folder or the current folder, Neri will use the option settings written in `neri.config` without you having to enter each of the above options.

Enter the above options in `neri.config`, separated by a new line as shown below.

```
--icon myicon.ico
--encryption-key foo
--output-dir ../bar
```

Command line options ← Current folder ← Home folder takes precedence in this order.

## Simple file hiding function using the data file

For example, you can put not only script.rb but also all the files in the data folder into a data file by doing the following.

    $ neri script.rb data/*

Script files in the data file can be loaded with `require` or `load`.

Also, by adding `require 'neri'` in the original script file, you can access the files in the data file with the following methods.

```ruby
Neri.file_exist?(filename) # -> bool
```

Returns true if the file exists in the data file or actually exists, false if it does not.

```ruby
Neri.file_read(filename, encoding = Encoding::BINARY) # -> String
```

Reads the entire file that exists in the data file or in as a real file file (the size to be read cannot be specified). If the file exists both in the data file and as a real file, the one in the data file takes precedence.

```ruby
Neri.files # -> Array
```

Returns a list of files in a data file as Array.

### Cooperation with DXRuby, etc.

When using DXRuby, Neri will overwrite DXRuby's Image.load, Image.load_tiles, and Sound.new, and load from the image and sound files in the data file if there are any.
This allows you to use Neri for simple file hiding without having to rewrite any script files.

### Other

#### If you want to exit the script early only when the executable is created

Neri executes the script once to check for dependency files, so you need to wait for it to finish or force it to quit in the middle. However, since the module `NeriBuild` is present when the executable is created, you can make it exit early if `NeriBuild` is present, as follows.

```ruby
require "foobar"
# All necessary libraries have been loaded.
exit if defined? NeriBuild
```

#### Path of the executable file

When you run an executable created by Neri, the path of the executable will be saved in the environment variable `NERI_EXECUTABLE`.

```ruby
puts ENV["NERI_EXECUTABLE"]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nodai2hITC/neri

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
