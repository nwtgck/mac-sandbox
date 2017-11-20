# This script is to make a "myroot" directory

require 'yaml'
require 'fileutils'

# Path of environment yaml
ENVIRONMENT_YAML_PATH = './environment.yaml'

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

puts "Destination of chroot is '#{CH_ROOT}'"

if Dir.exist? CH_ROOT
  # Remove CH_ROOT directory to clean
  # FileUtils.rm_r(CH_ROOT)
  system("sudo rm -rf #{CH_ROOT}")
end

# Load yaml
env_yaml = YAML.load_file(ENVIRONMENT_YAML_PATH)

# Files and directories to be brought
export_files = env_yaml["files_and_directories"]

# Unresolved executable files
non_resolved_app_paths = env_yaml["executables"]


# Confirm whether the executables and files
(non_resolved_app_paths+export_files).each{|app_path|
  if !File.exist?(app_path)
    puts "'#{app_path}' not found"
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

# Make $CHROOT/var/run directory
system("mkdir -p #{CH_ROOT}/var/run")
# Link mDNSResponder (this is necessary for curl to solve in curl)
system("ln /var/run/mDNSResponder #{CH_ROOT}/var/run/")

puts
puts "OS setup is done!"
