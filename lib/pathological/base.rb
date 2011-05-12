module Pathological
  PATHFILE_NAME = "Pathfile"

  class PathException < RuntimeError; end

  def self.add_paths
    root = find_pathfile
    pathfile = File.join(root, PATHFILE_NAME)
    raise PathException, "No Pathfile found." if pathfile.nil?
    pathfile_lines= File.open(pathfile).read.split("\n")
    paths = parse_pathfile(root, pathfile_lines)
    paths.each { |path| $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path) }
  end

  # private module methods

  def self.find_pathfile
    current_directory = File.expand_path($0)
    until current_directory == "/"
      current_directory = File.dirname(current_directory)
      pathfile = File.join(current_directory, PATHFILE_NAME)
      return current_directory if File.file? pathfile
    end
    nil
  end

  def self.parse_pathfile(root, pathfile_lines)
    options = { :exclude_root => false, :no_exceptions => false }
    paths = [root]
    pathfile_lines.each do |line|
      # Trim comments
      # TODO(caleb): Maybe we only want to allow for comments with # at the beginning of the line? That way
      # we won't screw up paths with # in them.
      line = line.split(/#/, 2)[0].strip
      next if line.empty?
      if line.start_with? ">"
        set_option!(line[1..-1].strip, options)
      else
        paths << File.expand_path(File.join(root, line))
      end
    end

    paths.uniq!
    unless options[:no_exceptions]
      paths.each do |path|
        unless File.directory? path
          raise PathException, "Bad path in Pathfile: #{path}"
        end
      end
    end
    paths.reject! { |path| File.expand_path(path) == File.expand_path(root) } if options[:exclude_root]
    paths
  end

  def self.set_option!(option, options)
    option = option.to_s.gsub("-", "_").to_sym
    raise PathException, "Bad option: #{option}" unless options.include? option
    if options[option]
      raise PathException, "Option set twice in Pathfile"
    else
      options[option] = true
    end
  end

  private_class_method :find_pathfile, :parse_pathfile, :set_option!
end
