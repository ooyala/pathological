require "rubygems"
require "scope"
require "rr"
require "minitest/autorun"
require "stringio"

require "pathological/base"

module Pathological
  class BaseTest < Scope::TestCase
    include RR::Adapters::RRMethods

    def assert_load_paths_equal(this, other)
      assert_equal this.uniq.sort, other.uniq.sort
    end

    def create_pathfile(text, path = "/a/b/c/Pathfile")
      pathfile = StringIO.new(text)
      stub(pathfile).path { path }
    end

    def load!
      Pathological.add_paths(@load_path)
    end

    setup do
      # Stubbed out our view of the filesystem for the pathfile
      stub(File).open do |path|
        if path == @pathfile[:path]
          stub!.read { @pathfile[:contents] }
        else
          raise "file not found"
        end
      end
      @current_file = "/a/b/c/myfile.rb"
      @load_path = []
      @stderr_output = []
      @stderr = STDERR
      stub(File).expand_path { |f| (f == $0) ? @current_file : f }
      stub(File).file? { |path| path == @pathfile[:path] }
      stub(File).directory? { |path| @directories.include?(path) }
    end

    context "loading pathological with no pathfile" do
      should "not raise an error" do
        create_pathfile("/a/b/d/Pathfile", "anything...")
        @stderr = mock(STDERR).puts(/^Warning/)
        load!
      end
    end

    # Let's break through the abstraction here for a second in order to separate testing the pathfile-location
    # functionality from the other things.
    context "pathfile location function" do
      should "find a pathfile in this directory" do
        create_pathfile("whatever, man", "/a/b/c/Pathfile")
        assert_equal "/a/b/c", Pathological.send(:find_pathfile)
      end

      should "find a pathfile in a parent directory" do
        create_pathfile("it's cool", "/a/b/Pathfile")
        assert_equal "/a/b", Pathological.send(:find_pathfile)
      end

      should "find a pathfile at the root" do
        create_pathfile("I DO WHAT I WANT", "/Pathfile")
        assert_equal "/", Pathological.send(:find_pathfile)
      end
    end

    context "loading pathological" do
      setup do
        # Kinda ugly because of my ugly stubs for File#directory? and other methods
        @directories = [ "/a/b/c", "/a/b/c/foo", "/a/b/c/../bar", "/a/b/d/baz" ]
      end

      should "use an empty Pathfile correctly" do
        create_pathfile("")
        load!
        assert_load_paths_equal [ "/a/b/c" ], @load_path
      end

      should "add some paths as appropriate" do
        create_pathfile(<<-EOS)
          foo
          ../bar
        EOS
        load!
        assert_load_paths_equal [ "/a/b/c", "/a/b/c/foo", "/a/b/c/../bar" ], @load_path
      end

      should "throw exceptions on bad load paths" do
        create_pathfile("quux")
        assert_raises(PathException) { load! }
      end

      should "allow bad paths with appropriate option" do
        create_pathfile(<<-EOS)
          > no-exceptions
          quux
        EOS
        load!
        assert_load_paths_equal [ "/a/b/c", "/a/b/c/quux" ], @load_path
      end

      should "exclude root with that option" do
        create_pathfile(<<-EOS)
          > exclude-root
          foo
        EOS
        load!
        assert_load_paths_equal [ "/a/b/c/foo", ], @load_path
      end

      should "raise an error with a bad option" do
        create_pathfile("> asdf")
        assert_raises(PathException) { load! }
      end
    end
  end
end
