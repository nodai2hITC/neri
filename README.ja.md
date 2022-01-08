# Neri

Neri は、Ruby スクリプトを Ruby 未インストール環境の Windows 向けに配布するためのパッケージングシステムです。

同種の gem としては [OCRA](https://github.com/larsch/ocra) がありますが、以下のような違いがあります。

- OCRA に比べての長所
  - 展開しない分、起動が速い。
  - 実行ファイルを複数作りたいとき、OCRA ではサイズの大きな実行ファイルを複数生成することになってしまうが、Neri ではシステムファイルを共有できるため全体のサイズが大きくならずに済む。
  - OCRA には「日本語を含むユーザー名の環境では起動できない」という問題があるが、Neri にはない。
- OCRA に比べての短所
  - 基本的に、[Ruby Installer 2](https://rubyinstaller.org/) With Devkit で Ruby をインストールした環境でしか利用できない。（なお、使用前に `ridk enable` を実行してパスを通す必要があります。）

## インストール

    $ gem install neri

bundler を用いた利用もできますが、その場合同梱するファイルが増えてしまうのでおすすめしません。

## 使い方

まず、`ridk enable` を実行して開発環境にパスを通す必要があります。

    $ neri [options] script.rb (other_files...) -- script_arguments

上の例では、一度 "script.rb" を依存ファイルチェックのために実行し、
その際に必要としたファイルを依存ファイルとして出力先にコピーした上で、
実行ファイルを作成します。

出力先フォルダを丸ごとコピーすれば、Ruby 未インストール環境でもスクリプトを実行できます。

### options:

#### 基本オプション

<dl>
  <dt>--help or -h</dt>
  <dd>ヘルプを表示します。</dd>
  <dt>--version or -v</dt>
  <dd>バージョンを表示します。</dd>
  <dt>--quiet</dt>
  <dd>実行中に途中経過等を表示しなくなります。</dd>
</dl>

#### 依存ファイルの追加

Neri は実行時に必要と思われるファイルを自動的に依存ファイルとして出力先にコピーしますが、
その判定がうまくいかず実行に必要なファイルが足りない場合もあります。
そうした場合はこれらのオプションで依存ファイルを手動で追加する必要があります。

（もしくは、直接出力先に手動で必要なファイルをコピーするのも1つの方法です。）

<dl>
  <dt>--dll &lt;dll1&gt;,&lt;dll2&gt;,...</dt>
  <dd>bin フォルダ内の指定された dll ファイルを依存ファイルに追加します。</dd>
  <dt>--lib &lt;lib1&gt;,&lt;lib2&gt;,...</dt>
  <dd>ロードパス（$LOAD_PATH）内の指定されたファイルを依存ファイルに追加します。</dd>
  <dt>--gem &lt;gem1&gt;,&lt;gem2&gt;,...</dt>
  <dd>指定された gem のファイルを依存ファイルに追加します。
  デフォルトでは、該当 gem の lib フォルダ内のファイル一式を依存ファイルに追加します。（たとえば `--gem gemname:dir1|dir2` とすれば、lib フォルダ以外のファイルを追加できます。）
  現状、gem 間の依存等はチェックしないので、必要な gem すべてを手動で追加する必要があります。</dd>
</dl>

#### 文字コード関係

Neri はデフォルトでは、enc フォルダ内の文字コードライブラリをすべて依存ファイルに加えますが、
その分全体のファイルサイズが大きくなってしまいます。
これらのオプションでコピーする文字コードライブラリを指定することで、最小限のデータ量にすることができます。

<dl>
  <dt>--no-enc</dt>
  <dd>文字コード関係ファイルを、実際に使用したもの以外は依存ファイルに加えないようにします。</dd>
  <dt>--encoding &lt;enc1&gt;,&lt;enc2&gt;,...</dt>
  <dd>追加する文字コード関係ファイルを手動で指定します。</dd>
</dl>

↓ 使用例："windows_31j.so", "japanese_sjis.so" のみを依存ファイルに追加します。

    $ neri --encoding windows_31j.so,japanese_sjis.so script.rb

#### 設定

<dl>
  <dt>--enable-gems</dt>
  <dd>rubygems を使用します。このオプションを使わない場合、依存チェック時に使用した gem のファイルは vendor_ruby フォルダ内にコピーされ、rubygems 無しでも実行できるようになります。</dd>
  <dt>--enable-did-you-mean</dt>
  <dd>did_you_mean を使用します。</dd>
  <dt>--no-chdir</dt>
  <dd>Neri で作成した実行ファイルは、デフォルトでは実行時にカレントフォルダを実行ファイルと同じフォルダに設定します。このオプションを使うとカレントフォルダを変更しなくなります。（このオプションを使うと、日本語フォルダ下などではうまく動かなくなる可能性があるので注意してください。）</dd>
  <dt>--pause-last</dt>
  <dt>--no-pause-last</dt>
  <dd>実行の最後に、pause を入れるか否かを設定します。省略した場合、コンソールアプリ（後述）の場合 on に、ウィンドウアプリの場合 off になります。</dd>
  <dt>--pause-text &lt;text&gt;</dt>
  <dd>pause を入れる場合の表示内容を設定します。</dd>
</dl>

#### 出力関係

<dl>
  <dt>--output-dir &lt;dirname&gt;</dt>
  <dd>出力先フォルダ名を指定します。省略すると、カレントフォルダ（./）になります。</dd>
  <dt>--system-dir &lt;dirname&gt;</dt>
  <dd>ruby 等がコピーされる、システムフォルダ名を指定します。デフォルトは "system" です。</dd>
  <dt>--datafile &lt;filename&gt;</dt>
  <dd>データファイル名を指定します。省略した場合、実行スクリプトファイルのファイル名の拡張子を ".dat" に変更したものになります。
  なお、このオプションを省略＆実行スクリプトファイル以外にデータファイルに入れるファイルが無い場合、データファイルは作成されず、実行スクリプトファイルがそのままシステムフォルダ内にコピーされます。</dd>
  <dt>--encryption-key &lt;key&gt;</dt>
  <dd>データファイルの暗号化キーを設定します。省略した場合、暗号化は行われません。
  暗号化は簡単なものなので、解読されては困るような重要なデータには用いないでください。</dd>
  <dt>--virtual-directory &lt;dirname&gt;</dt>
  <dd>データファイルからファイルを読み出す際、Neri はまず実行時のカレントフォルダをもとにファイルを検索し、見つからない場合はこの virtual-directory をもとにファイルを検索します。省略した場合は自動的に適切な仮想パスを生成します。</dd>
</dl>

#### exe ファイルの作成

<dl>
  <dt>--no-exe or --bat</dt>
  <dd>exe ファイルは作成せず、bat ファイルを作成します。</dd>
  <dt>--icon &lt;iconfile&gt;</dt>
  <dd>アイコンを設定します。</dd>
  <dt>--windows or --invisible</dt>
  <dt>--console or --visible</dt>
  <dd>ウィンドウアプリにするかコンソールアプリにするかを設定します。
  ウィンドウアプリの場合、いわゆる「DOS窓」が開きません。
  省略した場合、実行スクリプトファイルの拡張子が ".rbw" の場合、あるいは [DXRuby](http://dxruby.osdn.jp/) や [Gosu](https://www.libgosu.org/ruby.html), [LibUI](https://github.com/kojix2/libui) を使用する場合にはウィンドウアプリになります。
  そうでない場合はコンソールアプリになります。</dd>
  <dt>--fileversion &lt;version&gt;</dt>
  <dt>--productversion &lt;version&gt;</dt>
  <dd>ファイルバージョン・製品バージョンを設定します。
  &lt;version&gt; は、1,2,3,4 のように４つの数字をカンマ区切りで設定します。</dd>
  <dt>--productname &lt;string&gt;</dt>
  <dt>--internalname &lt;string&gt;</dt>
  <dt>--description &lt;string&gt;</dt>
  <dt>--company &lt;string&gt;</dt>
  <dt>--trademarks &lt;string&gt;</dt>
  <dt>--copyright &lt;string&gt;</dt>
  <dd>製品名・内部名・ファイルの説明・会社名・商標・著作権を設定します。</dd>
  <dt>--privatebuild &lt;string&gt;</dt>
  <dt>--specialbuild &lt;string&gt;</dt>
  <dt>--comments &lt;string&gt;</dt>
  <dd>コメント等を設定します。</dd>
</dl>

### neri.config ファイルによる設定

HOME フォルダ、あるいはカレントフォルダに`neri.config`というファイルを用意しておくと、以上のオプションをいちいち入力しなくても、`neri.config`に書かれたオプション設定を使用します。

`neri.config`には上記のオプションを、下のように改行で区切って入力してください。

```
--icon myicon.ico
--encryption-key foo
--output-dir ../bar
```

コマンドラインオプション←カレントフォルダ←ホームフォルダの順で優先されます。

## データファイルを活用したファイルの簡易隠蔽機能

たとえば以下のようにすることで、script.rb だけでなく、data フォルダ内のデータ一式をデータファイルに収めることができます。

    $ neri script.rb data/*

データファイル内のスクリプトファイルは、`require` や `load` で読み込むことができます。

また、元のスクリプトファイルで `require 'neri'` しておくことで、以下のような命令でデータファイル内のデータにアクセスできます。

```ruby
Neri.file_exist?(filename) # -> bool
```

ファイルが「データファイル内」または「実際に」存在すれば true を、無ければ false を返します。

```ruby
Neri.file_read(filename, encoding = Encoding::BINARY) # -> String
```

「データファイル内」または「実際に」存在するファイルをまるごと読み込みます（読み込むサイズは指定できません）。データファイル内にも実ファイルとしても存在する場合、データファイル内のものが優先されます。

```ruby
Neri.files # -> Array
```

データファイル内にあるファイルの一覧を配列で返します。

### DXRuby 等との連携

DXRuby を使用する場合、DXRuby の Image.load, Image.load_tiles, Sound.new を上書きし、データファイル内に画像・音声ファイルがあればそちらから読み込むようになります。
これにより、スクリプトファイルを一切書き換えることなく、Neri を利用したファイルの簡易隠蔽機能が利用できます。

### その他

#### 実行ファイル作成時のみ、スクリプトを早期に終了させたい場合

Neri は依存ファイルチェックのためにスクリプトを一度実行するので、その終了を待つか途中で強制終了させる必要があります。しかし、実行ファイル作成時には `NeriBuild` というモジュールが存在するので、以下のように `NeriBuild` が存在する場合は早期に終了するようにすることができます。

```ruby
require "foobar"
# 必要なライブラリの読み込みがすべて終了
exit if defined? NeriBuild
```

#### 実行ファイルのパス

Neri で作られた実行ファイルを実行すると、環境変数 `NERI_EXECUTABLE` に実行ファイルのパスが保存されます。

```ruby
puts ENV["NERI_EXECUTABLE"]
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nodai2hITC/neri

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
