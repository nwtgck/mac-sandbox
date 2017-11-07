# 使い方
# ruby thisfileでchrootできる環境を作る
# 再度同じコマンドを打てば前の環境を削除して新しく作り直す

require 'fileutils'

# If command line arg is not valid
if ARGV.length != 1
  # Output usage and exit program
  STDERR.puts("Usage: ruby makeup.rb <myroot dir>")
  exit(1)
end

# app_pathに関する依存しているappを配列で返す
def get_dependencies app_path #=> returns [app_path]
  `otool -L #{app_path}`.scan(%r{\t(.+) \(.+\)}).flatten
end

# ルート権限による実行をやめた（brewのインストール時にも怒るので）
# if ENV['USER'] != 'root'
#   puts "実行権限をrootにしてください(sudoとかを使って下さい)"
#   exit
# end

# ROOTにしたいディレクトリ
CH_ROOT = File.absolute_path(ARGV[0])

BREW_DIR_NAME = "homebrew"

puts "chroot先は #{CH_ROOT} です"

if Dir.exist? CH_ROOT
  # CH_ROOTをまっさらにするために消す
  # FileUtils.rm_r(CH_ROOT)
  system("sudo rm -rf #{CH_ROOT}")
end

# 転送したいファイルやディレクトリ
export_files = [
  "/usr/bin/cd", # cdはファイルになっている
  "/usr/bin/gem", # gemもファイルになっている
  "/usr/bin/irb", # irbもファイルになっている
  "/System/Library/LaunchDaemons/com.apple.mDNSResponder.plist",
  "/System/Library/Frameworks/Ruby.framework",
  "/etc/resolv.conf", # インターネットに繋ぐために必要
  "/etc/hosts",
  "/Library/Keychains/",
  "/Library/Preferences/SystemConfiguration/", # http://yamaqblog.tokyo/?p=938
  "/etc/sudoers",
]

# 未解決なapp(/bin/shとか/bin/bashとかを書けばいい)
non_resolved_app_paths = [
  # これは不可欠なものらしい
  "/usr/lib/dyld", "/usr/lib/libSystem.B.dylib", "/usr/lib/libgcc_s.1.dylib", "/usr/lib/system/libmathCommon.A.dylib",
  # 欲しいものを列挙
  "/usr/bin/which",
  "/bin/ls",
  "/bin/sh",
  "/bin/bash",
  "/bin/mkdir",
  "/bin/rm",
  "/bin/rmdir",
  "/bin/ps",
  "/bin/cat",
  "/usr/bin/sudo",
  "/bin/chmod",
  "/usr/bin/tar",
  "/usr/bin/make",
  "/usr/bin/vi",
  "/usr/bin/vim",
  "/usr/bin/perl",
  "/usr/bin/perl5.18",
  "/sbin/ifconfig",
  "/usr/bin/grep",
  "/usr/bin/tee",
  "/usr/bin/nano",    # エラーで使えない（Error opening terminal: xterm-256color.
  "/usr/bin/touch",
  "/usr/bin/telnet", # 名前解決ができない
  "/usr/bin/ssh",    # Killed: 9のエラー
  "/usr/bin/dig",    # 正常に名前解決可能
  "/usr/sbin/networksetup",
  "/usr/bin/java",    # エラーで使えない（2016-09-26 14:44:24.304 java[17447:3497666] [JVM Detection] FillMatcher: failed to create CFNumberFormatter
  "/usr/bin/javac",   # エラーで使えない（2016-09-26 14:44:13.512 javac[17445:3497466] [JVM Detection] FillMatcher: failed to create CFNumberFormatter
  "/usr/bin/ld",
  "/sbin/ping",       # pingはKilled: 9と出て使えない（おそらくインターネットに繋げないため）
  "/usr/bin/curl",    # curl google.comとすれば「curl: (6) Could not resolve host: google.com」となって使えない
  "/usr/bin/ruby",    # うごくようになった（irbも動く)
  "/usr/bin/nslookup",
  "/usr/bin/openssl",
  "/bin/launchctl",
  "/usr/bin/git",    # Xcodeのインストールが求められる
  # "/usr/bin/gcc" Xcodeのインストールが求められる（これが原因でこのプロジェクト？をやめようと思った）
]

# # /usr/binのコマンドを全部入れる
# non_resolved_app_paths.push(*Dir.glob("/usr/bin/*"))

# sbinのコマンドを全部入れる
# non_resolved_app_paths.push(*Dir.glob("/usr/sbin/*"))

# インストールしたいappと転送したいファイルがちゃんとあるか確認する
(non_resolved_app_paths+export_files).each{|app_path|
  if !File.exist?(app_path)
    puts "'#{app_path}' が見つかりません"
    exit
  end
}

# 解決済みのappになる
resolved_app_paths = []

# 表示用（依存関係の表示したときの前に出力した文字列の長さ（この文はスペースで消す））
resolveing_str_length = 0

while !non_resolved_app_paths.empty?

  # 解決したいappを取得
  app_path = non_resolved_app_paths.shift

  # app_pathの依存関係を配列で取得
  new_app_paths = get_dependencies app_path

  # 解決済みに入れる
  resolved_app_paths << app_path
  resolved_app_paths.uniq!

  # 新しく未解決なappとして追加
  non_resolved_app_paths.push(*new_app_paths)
  non_resolved_app_paths.uniq!

  # 未解決パスがすべて解決済みなら
  if non_resolved_app_paths - resolved_app_paths == []
    # 終了
    break
  end

  # 依存関係の進捗を表示
  print("\r"+" "*resolveing_str_length)
  resolveing_str = "\rResolveing... #{resolved_app_paths.size}/#{resolved_app_paths.size+non_resolved_app_paths.size} #{app_path}"
  print resolveing_str
  resolveing_str_length = resolveing_str.size

end
puts
puts "Resolved"

resolved_and_files = resolved_app_paths+export_files

# 解決済みのパスと送りたいファイル（ディレクトリ）を包んでいる親ディレクトリたちを取得
parent_dirs = (resolved_and_files).map{|e| File.dirname(e)}
# 親ディレクトリたちを作成
parent_dirs.each{|dir|
  # なければディレクトリを作る mkdir -pと同じ
  FileUtils.mkdir_p("#{CH_ROOT}#{dir}")
}

(resolved_and_files).each_with_index{|app_path, i|
  # appと転送したいファイル（ディレクトリ）をCH_ROOTに同じディレクトリ階層にコピー
  # FileUtils.cp_r(app_path, "#{CH_ROOT}#{app_path}")
  if Dir.exist?("#{CH_ROOT}#{app_path}")
    system("sudo rm -r #{CH_ROOT}#{app_path}")
  end
  # ルート権限によるコピーが必要
  system("sudo cp -r #{app_path} #{CH_ROOT}#{app_path}")
  # 進捗用の表示
  print "\rCopying... #{i+1}/#{resolved_and_files.size}"
}
puts
puts "OS setup is done!"

# Homebrewをこの方法でインストールしてbrew installしてらchroot内では外のパスがわからないため、brew installしたものが使えないので、やめた
# puts "Installing Homebrew..."
# # BREWのディレクトリを作る
# system("mkdir #{CH_ROOT}/#{BREW_DIR_NAME}")
# # Githubから持ってくる
# system("curl -L https://github.com/Homebrew/homebrew/tarball/master > #{CH_ROOT}/master")
#
# # system("curl -L https://github.com/Homebrew/homebrew/tarball/master | tar xz --strip 1 -C #{CH_ROOT}/#{BREW_DIR_NAME}")
# # brewのパスを通す
# # system("export PATH=/#{BREW_DIR_NAME}/bin:$PATH >> ~/.bash_profile")
# # brew updateしないとbrew installなどができないみたい（なぜか）（最後にError: Could not link:とかと出てもinstallは動く）
# system("#{CH_ROOT}/#{BREW_DIR_NAME}/bin/brew update")
#
#
# puts("Done!")
# puts
# puts("Error: Could not link:とかと出てもinstallは動きます")
# puts("chroot #{CH_ROOT} の中ではインターネットにつながらないので、")
# puts("#{CH_ROOT}/#{BREW_DIR_NAME}/bin/brew install wget　みたいに実行して必要なものを予めインストールすればOKです")
