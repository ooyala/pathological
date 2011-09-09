require "pathname"

module Pathological
  PATHFILE_NAME = "Pathfile"


  class PathologicalException < RuntimeError; end
  class NoPathfileException < PathologicalException; end

  # Add paths to the load path.
  #
  # @param [String] load_path the load path to use.
  # @param [Array<String>] paths the array of new load paths (if +nil+, the result of {find_load_paths}).
  def self.add_paths!(load_path = $LOAD_PATH, paths = nil)
    begin
      paths ||= find_load_paths
    rescue NoPathfileException
      STDERR.puts "Warning: using Pathological, but no Pathfile was found."
      return
    end
    paths.each do |path|
      if load_path.include? path
        debug "Skipping <#{path}>, which is already in the load path."
      else
        debug "Adding <#{path}> to load path."
        load_path << path
        @@loaded_paths << path
      end
    end
  end

  # For some pathfile, parse it and find all the load paths that it references.
  #
  # @param [String, nil] pathfile the pathfile to inspect. Uses {find_pathfile} if +nil+.
  # @return [Array<String>] the resulting array of paths.
  def self.find_load_paths(pathfile = nil)
    pathfile ||= find_pathfile
    raise NoPathfileException unless pathfile
    begin
      pathfile_handle = File.open(pathfile)
    rescue Errno::ENOENT
      raise NoPathfileException
    rescue
      raise PathologicalException, "There was an error opening the pathfile <#{pathfile}>."
    end
    parse_pathfile(pathfile_handle)
  end

  # Find the pathfile by searching up from a starting directory. Symlinks are expanded out.
  #
  # @param [String] directory the starting directory. Defaults to the directory containing the running file.
  # @return [String, nil] the absolute path to the pathfile (if it exists), otherwise +nil+.
  def self.find_pathfile(directory = nil)
    # If we're in IRB, use the working directory as the root of the search path for the Pathfile.
    if $0 != __FILE__ && $0 == "irb"
      directory = Dir.pwd
      debug "In IRB -- using the cwd (#{directory}) as the search root for Pathfile."
    end
    return nil if directory && !File.directory?(directory)
    # Find the full, absolute path of this directory, resolving symlinks. If no directory was given, use the
    # directory where the executed file resides.
    full_path = real_path(directory || $0)
    current_path = directory ? full_path : File.dirname(full_path)
    loop do
      debug "Searching <#{current_path}> for Pathfile."
      pathfile = File.join(current_path, PATHFILE_NAME)
      if File.file? pathfile
        debug "Pathfile found: <#{pathfile}>."
        return pathfile
      end
      new_path = File.dirname current_path
      if new_path == current_path
        debug "Reached filesystem root, but no Pathfile found."
        return nil
      end
      current_path = new_path
    end
  end

  # Convenience functions for the various modes in which Pathological may run.

  def self.debug_mode; @@debug = true; end
  def self.bundlerize_mode
    pathfile = Pathological.find_pathfile
    raise NoPathfileException unless pathfile
    bundle_gemfile = File.join(File.dirname(pathfile), "Gemfile")
    unless File.file? bundle_gemfile
      raise PathologicalException, "No Gemfile found in #{File.dirname(pathfile)}."
    end
    ENV["BUNDLE_GEMFILE"] = bundle_gemfile
  end
  def self.parentdir_mode; @@add_parents = true; end
  def self.noexceptions_mode; @@no_exceptions = true; end
  def self.excluderoot_mode; @@exclude_root = true; end

  # Reset all Pathological options (useful if you want to require a different Pathfile)
  def self.reset!
    # Debug mode -- print out information about load paths
    @@debug = false
    # Parentdir mode -- add unique parents of specified directories.
    @@add_parents = false
    # Noexceptions mode -- don't raise exceptions if the Pathfile contains bad paths
    @@no_exceptions = false
    # Excluderoot mode -- don't add the project root (where the Pathfile lives) to the load path
    @@exclude_root = false

    @@loaded_paths ||= []
    @@loaded_paths.each { |path| $LOAD_PATH.delete path }
    @@loaded_paths = []
  end

  # private module methods

  # Print debugging info
  #
  # @private
  # @param [String] message the debugging message
  # @return [void]
  def self.debug(message); puts "[Pathological Debug] >> #{message}" if @@debug; end

  # Turn a path into an absolute path with no useless parts and no symlinks.
  #
  # @private
  # @param [String] the path
  # @return [String] the absolute real path
  def self.real_path(path); Pathname.new(path).realpath.to_s; end

  # Parse a pathfile and return the appropriate paths.
  #
  # @private
  # @param [IO] pathfile handle to the pathfile to parse
  # @return [Array<String>] array of paths found
  def self.parse_pathfile(pathfile)
    root = File.dirname(real_path(pathfile.path))
    raw_paths = [root]
    pathfile.each do |line|
      # Trim comments
      line = line.split(/#/, 2)[0].strip
      next if line.empty?
      raw_path = File.expand_path(File.join(root, line.strip))
      raw_paths << (@@add_parents ? File.dirname(raw_path) : raw_path)
    end

    paths = []
    raw_paths.each do |path|
      unless File.directory? path
        unless @@no_exceptions
          raise PathologicalException, "Bad path in Pathfile: #{path}"
        end
        debug "Ignoring non-existent path: #{path}"
        next
      end
      next if @@exclude_root && File.expand_path(path) == File.expand_path(root)
      paths << path
    end
    @@exclude_root ? paths.reject { |path| File.expand_path(path) == File.expand_path(root) } : paths
  end

  private_class_method :debug, :real_path, :parse_pathfile

  # Reset options
  Pathological.reset!
end
