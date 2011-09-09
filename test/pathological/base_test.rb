require "rubygems"
require "scope"
require "rr"
require "minitest/autorun"
require "stringio"
require "fakefs/safe"

# It's kind of funny that we need to do this hack, given that Pathological is intended to work around it...
$:.unshift(File.join(File.dirname(__FILE__), "../../lib"))
require "pathological/base"

module Pathological
  class BaseTest < Scope::TestCase
    include RR::Adapters::MiniTest
    def assert_load_path(expected_load_path)
      assert_equal expected_load_path.uniq.sort, @load_path.uniq.sort
    end

    context "Pathological" do
      setup_once { FakeFS.activate! }
      setup do
        Pathological.reset!
        @load_path = []
        FakeFS::FileSystem.clear
        # FakeFS has not implemented the necessary calls for Pathname#realpath to work.
        stub(Pathological).real_path(anything) { |p| p }
      end
      teardown_once { FakeFS.deactivate! }

      context "#add_paths!" do
        should "not raise an error but print a warning when there's no pathfile" do
          mock(Pathological).find_pathfile { nil }
          mock(STDERR).puts(anything) { |m| assert_match /^Warning/, m }
          Pathological.add_paths! @load_path
          assert_load_path []
        end

        should "append the requested paths" do
          paths = ["foo"]
          Pathological.add_paths! @load_path, paths
          assert_load_path paths
        end

        should "append the paths that #find_load_paths finds" do
          paths = ["foo"]
          mock(Pathological).find_load_paths { paths }
          Pathological.add_paths! @load_path
          assert_load_path paths
        end
      end

      context "#find_load_paths" do
        should "raise a NoPathfileException on a nil pathfile" do
          mock(Pathological).find_pathfile { nil }
          assert_raises(NoPathfileException) { Pathological.find_load_paths(nil) }
        end

        should "use #find_pathfile to find the Pathfile and #parse_pathfile to parse it." do
          paths = ["path1"]
          mock(Pathological).find_pathfile { "foo" }
          mock(File).open("foo") { "bar" }
          mock(Pathological).parse_pathfile("bar") { paths }
          assert_equal paths, Pathological.find_load_paths
        end
      end

      context "#find_pathfile" do
        setup do
          @working_directory = "/foo/bar/baz"
          FileUtils.mkdir_p @working_directory
          FileUtils.cd @working_directory
        end

        should "find a pathfile in this directory" do
          pathfile = "/foo/bar/baz/Pathfile"
          FileUtils.touch pathfile
          assert_equal pathfile, Pathological.find_pathfile(@working_directory)
        end

        should "find a pathfile in a parent directory" do
          pathfile = "/foo/bar/Pathfile"
          FileUtils.touch pathfile
          assert_equal pathfile, Pathological.find_pathfile(@working_directory)
        end

        should "find a pathfile at the root" do
          pathfile = "/Pathfile"
          FileUtils.touch pathfile
          assert_equal pathfile, Pathological.find_pathfile(@working_directory)
        end

        should "locate a pathfile in the real path even if we're running from a symlinked directory" do
          pathfile = "/foo/bar/baz/Pathfile"
          FileUtils.touch pathfile
          FileUtils.touch "/Pathfile" # Shouldn't find this one
          symlinked_directory = "/foo/bar/quux"
          FileUtils.ln_s @working_directory, symlinked_directory
          stub(Pathological).real_path(anything) { |path| path.gsub("quux", "baz") }
          assert_equal pathfile, Pathological.find_pathfile(@working_directory)
        end
      end

      context "loading pathological" do
        setup do
          @pathfile_contents = ""
          @pathfile = "/Pathfile"
          $0 = "/my_file"
          FileUtils.touch @pathfile
          FileUtils.cd "/"
        end

        # Load in pathfile contents and load Pathological
        def load_and_run!
          File.open(@pathfile, "w") { |f| f.write(@pathfile_contents) }
          Pathological.add_paths!(@load_path)
        end

        should "use an empty Pathfile correctly" do
          load_and_run!
          assert_load_path ["/"]
        end

        should "add some paths as appropriate" do
          paths = ["/foo/bar", "/baz"]
          paths.each do |path|
            FileUtils.mkdir_p path
            @pathfile_contents << "#{path}\n"
          end
          load_and_run!
          assert_load_path(paths << "/")
        end

        should "throw exceptions on bad load paths" do
          path = "/foo/bar"
          @pathfile_contents << "#{path}"
          assert_raises(PathologicalException) { load_and_run! }
        end

        should "print some debug info in debug mode" do
          Pathological.debug_mode
          mock(Pathological).puts(anything).at_least(3)
          Pathological.add_paths!
        end

        should "set $BUNDLE_GEMFILE correctly in bundlerize mode" do
          FileUtils.touch "/Gemfile"
          Pathological.bundlerize_mode
          Pathological.add_paths!
          assert_equal "/Gemfile", ENV["BUNDLE_GEMFILE"]
        end

        should "add the correct directories in parentdir mode" do
          paths = ["/foo/bar/baz1", "/foo/bar/baz2", "/foo/quux"]
          paths.each { |path| FileUtils.mkdir_p path }
          @pathfile_contents = paths.join("\n")
          Pathological.parentdir_mode
          load_and_run!
          assert_load_path ["/", "/foo/bar", "/foo"]
        end

        should "not raise exceptions on bad paths in noexceptions mode" do
          path = "/foo/bar"
          @pathfile_contents << path
          Pathological.noexceptions_mode
          load_and_run!
          assert_load_path ["/"]
        end

        should "not add the project root in excluderoot mode" do
          path = "/foo/bar"
          FileUtils.mkdir_p path
          @pathfile_contents << path
          Pathological.excluderoot_mode
          load_and_run!
          assert_load_path ["/foo/bar"]
        end
      end
    end
  end
end
