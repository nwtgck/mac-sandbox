# This script is to make a "myroot" directory

require 'fileutils'

# If command line arg is not valid
if ARGV.length != 1
  # Output usage and exit program
  STDERR.puts("Usage: ruby makeup.rb <myroot dir>")
  exit(1)
end

# Get dependencies which depends app_path
# @param [String]
# @return [Array<String>]
def get_dependencies app_path
  `otool -L #{app_path}`.scan(%r{\t(.+) \(.+\)}).flatten
end


# A directory which will be myroot
CH_ROOT = File.absolute_path(ARGV[0])

BREW_DIR_NAME = "homebrew"

puts "chroot先は #{CH_ROOT} です"

if Dir.exist? CH_ROOT
  # Remove CH_ROOT directory to clean
  # FileUtils.rm_r(CH_ROOT)
  system("sudo rm -rf #{CH_ROOT}")
end

# Files and directories to be brought
export_files = [
  "/usr/bin/cd", # cd is a file
  "/usr/bin/gem", # gem is also a file
  "/usr/bin/irb", # irb is a file too
  "/System/Library/LaunchDaemons/com.apple.mDNSResponder.plist",
  "/System/Library/Frameworks/Ruby.framework",
  "/etc/resolv.conf", # for connecting internet
  "/etc/hosts",
  "/Library/Keychains/",
  "/Library/Preferences/SystemConfiguration/", # (from: http://yamaqblog.tokyo/?p=938)
  "/etc/sudoers",
]

# Unresolved executable files
non_resolved_app_paths = [
  # They seem to be essential
  "/usr/lib/dyld", "/usr/lib/libSystem.B.dylib", "/usr/lib/libgcc_s.1.dylib", "/usr/lib/system/libmathCommon.A.dylib",
  # List all you need
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
  "/usr/bin/nano",    # NOT-WORK（Error opening terminal: xterm-256color.
  "/usr/bin/touch",
  "/usr/bin/telnet", # cann't resolve name
  "/usr/bin/ssh",    # Error (Killed: 9)
  "/usr/bin/dig",    # WORK! (resolve name)
  "/usr/sbin/networksetup",
  "/usr/bin/java",    # NOT-WORK（2016-09-26 14:44:24.304 java[17447:3497666] [JVM Detection] FillMatcher: failed to create CFNumberFormatter
  "/usr/bin/javac",   # NOT-WORK（2016-09-26 14:44:13.512 javac[17445:3497466] [JVM Detection] FillMatcher: failed to create CFNumberFormatter
  "/usr/bin/ld",
  "/sbin/ping",       # NOT-WORK (Killed: 9)
  "/usr/bin/curl",    # if curl google.com, it says "curl: (6) Could not resolve host: google.com"
  "/usr/bin/ruby",    # WORK! (irb works too)
  "/usr/bin/nslookup",
  "/usr/bin/openssl",
  "/bin/launchctl",
  "/usr/bin/git",    # It will require Xcode installation
  # "/usr/bin/gcc" It will require Xcode installation
]


# Confirm whether the executables and files
(non_resolved_app_paths+export_files).each{|app_path|
  if !File.exist?(app_path)
    puts "'#{app_path}' が見つかりません"
    exit
  end
}

# This will be resolved executables
resolved_app_paths = []

# For display (this will be length of string which outputed)
resolveing_str_length = 0

while !non_resolved_app_paths.empty?

  # Get an executable which is wanted to solve
  app_path = non_resolved_app_paths.shift

  # Get the dependencies of app_path
  new_app_paths = get_dependencies app_path

  # Push app_path to resolved path
  resolved_app_paths << app_path
  resolved_app_paths.uniq!

  # Push new_app_paths as unresolved_app_path
  non_resolved_app_paths.push(*new_app_paths)
  non_resolved_app_paths.uniq!

  # If all path are resolved
  if non_resolved_app_paths - resolved_app_paths == []
    # finish resolving
    break
  end

  # Show progress
  print("\r"+" "*resolveing_str_length)
  resolveing_str = "\rResolveing... #{resolved_app_paths.size}/#{resolved_app_paths.size+non_resolved_app_paths.size} #{app_path}"
  print resolveing_str
  resolveing_str_length = resolveing_str.size

end
puts
puts "Resolved"

resolved_and_files = resolved_app_paths+export_files

# Get parent directories which wrap the resolved files
parent_dirs = (resolved_and_files).map{|e| File.dirname(e)}
# Make the all parents
parent_dirs.each{|dir|
  # Make a parent (mkdir -p)
  FileUtils.mkdir_p("#{CH_ROOT}#{dir}")
}

(resolved_and_files).each_with_index{|app_path, i|
  # Copy files in the same structure
  if Dir.exist?("#{CH_ROOT}#{app_path}")
    system("sudo rm -r #{CH_ROOT}#{app_path}")
  end
  # This copy needs the super user
  system("sudo cp -r #{app_path} #{CH_ROOT}#{app_path}")
  # Show progress
  print "\rCopying... #{i+1}/#{resolved_and_files.size}"
}
puts
puts "OS setup is done!"
