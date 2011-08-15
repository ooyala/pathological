require "pathname"

module Pathological
  PATHFILE_NAME = "Pathfile"

  # Debug mode -- print out information about load paths
  @@debug = false

  class PathologicalException < RuntimeError; end
  class NoPathfileException < PathologicalException; end

  # Add paths to the load path.
  #
  # @param [String] load_path the load path to use (default is $LOAD_PATH).
  # @param [Array<String>] paths the array of new load paths (if nil, the result of {self#find_load_paths}).
  # @return [void]
  def self.add_paths(load_path = $LOAD_PATH, paths = nil)
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
      end
    end
  end

  # For some pathfile, parse it and find all the load paths that it references.
  #
  # @param [String, nil] pathfile the pathfile to inspect. Uses {self#find_pathfile} if `nil`.
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
  # @return [String, nil] the absolute path to the pathfile (if it exists), otherwise `nil`.
  def self.find_pathfile(directory = File.dirname(File.expand_path($0)))
    # If we're in IRB, use the working directory as the root of the search path for the Pathfile.
    if $0 != __FILE__ && $0 == "irb"
      directory = Dir.pwd
      debug "In IRB -- using the cwd (#{directory}) as the search root for Pathfile."
    end
    return nil unless File.directory? directory
    # Find the full, absolute path of this directory, resolving symlinks:
    current_path = Pathname.new(File.expand_path(directory)).realpath.to_s
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

  # private module methods

  # Print debugging info
  #
  # @private
  # @param [String] message the debugging message
  # @return [void]
  def self.debug(message)
    puts "[Pathological Debug] >> #{message}" if @@debug
  end

  # Parse a pathfile and return the appropriate paths.
  #
  # @private
  # @param [IO] pathfile handle to the pathfile to parse
  # @return [Array<String>] array of paths found, taking into account options specified.
  def self.parse_pathfile(pathfile)
    options = { :exclude_root => false, :no_exceptions => false }
    root = File.dirname(Pathname.new(File.expand_path(pathfile.path)).realpath.to_s)
    raw_paths = [root]
    pathfile.each do |line|
      # Trim comments
      line = line.split(/#/, 2)[0].strip
      next if line.empty?
      if line.start_with? ">"
        set_option!(line[1..-1].strip, options)
      else
        raw_paths << File.expand_path(File.join(root, line))
      end
    end

    debug "Pathfile options: #{options.inspect}"
    paths = []
    raw_paths.each do |path|
      unless File.directory? path
        unless options[:no_exceptions]
          raise PathologicalException, "Bad path in Pathfile: #{path}"
        end
        debug "Ignoring non-existent path: #{path}"
        next
      end
      next if options[:exclude_root] && File.expand_path(path) == File.expand_path(root)
    end
    paths.reject! { |path| File.expand_path(path) == File.expand_path(root) } if options[:exclude_root]
    paths
  end

  # Apply an option to the `options` hash.
  #
  # @private
  # @param [String] option the option to apply
  # @param [Hash] options the options hash to mutate
  # @return [void]
  def self.set_option!(option, options)
    option = option.to_s.gsub("-", "_").to_sym
    raise PathologicalException, "Bad option: #{option}" unless options.include? option
    if options[option]
      raise PathologicalException, "Option set twice in Pathfile"
    else
      options[option] = true
    end
  end

  private_class_method :debug, :parse_pathfile, :set_option!
end
