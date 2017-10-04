# Neri

[日本語説明（こちらの方が詳細）](https://github.com/nodai2hITC/neri/blob/master/README.ja.md)

## Installation

    $ gem install neri

## Usage

    $ neri [options] script.rb (other_files...) -- script_arguments

```
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
  --fileversion <version>
  --productversion <version>
  --company <company_name>
  --productname <name>
  --internalname <name>
  --description <description>
  --copyright <copyright>
  
  --use-upx
  --upx-path <upx path>
  --upx_targets '<glob>'
  --upx-options <options>
  
  --zipfile <filename>
  --7zip-path <7-zip path>
  
  --innosetup <inno_script>
  --iscc-path <iscc path>
  
  --create-recipe <recipefile>
  --recipe <recipefile>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nodai2hITC/neri

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
