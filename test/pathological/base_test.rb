require "rubygems"
require "scope"
require "rr"
require "minitest/autorun"
require "stringio"

require "pathological/base"

# Copy-pasted from RR Minitest adapter that I've submitted as a pull request to RR.
# TODO(caleb): delete
module RR
  module Adapters
    module MiniTest
      include RRMethods
      def self.included(mod)
        RR.trim_backtrace = true
        mod.class_eval do
          unless instance_methods.any? { |method_name| method_name.to_sym == :setup_with_rr }
            alias_method :setup_without_rr, :setup
            def setup_with_rr
              setup_without_rr
              RR.reset
            end
            alias_method :setup, :setup_with_rr

            alias_method :teardown_without_rr, :teardown
            def teardown_with_rr
              RR.verify
              teardown_without_rr
            end
            alias_method :teardown, :teardown_with_rr
          end
        end
      end

      def assert_received(subject, &block)
        block.call(received(subject)).call
      end
    end
  end
end

module Pathological
  class BaseTest < Scope::TestCase
    include RR::Adapters::MiniTest
    def assert_load_path(expected_load_path)
      assert_equal expected_load_path, @load_path.uniq.sort
    end

    def create_pathfile(text, path = "/a/b/c/Pathfile")
      pathfile = StringIO.new(text)
      stub(pathfile).path { path }
    end

    context "#add_paths" do
      setup do
        @load_path = []
      end

      should "not raise an error but print a warning when there's no pathfile" do
        mock(Pathological).find_pathfile { nil }
        mock(STDERR).puts(anything) { |m| assert_match /^Warning/, m }
        Pathological.add_paths @load_path
        assert_load_path []
      end

      should "append the requested paths" do
        paths = ["foo"]
        Pathological.add_paths @load_path, paths
        assert_load_path paths
      end

      should "append the paths that #find_load_paths finds" do
        paths = ["foo"]
        mock(Pathological).find_pathfile { paths }
        Pathological.add_paths @load_path, paths
        assert_load_path paths
      end
    end

    context "#find_load_paths" do
      should "raise a NoPathfileException on a nil pathfile" do
        mock(Pathological).find_pathfile { nil }
        assert_raises(NoPathfileException) { Pathological.find_load_paths(nil) }
      end

    end

    context "pathfile location function" do
      should "find a pathfile in this directory" do

      end

      should "find a pathfile in a parent directory" do
      end

      should "find a pathfile at the root" do
      end
    end

    context "loading pathological" do
      should "use an empty Pathfile correctly" do
      end

      should "add some paths as appropriate" do
      end

      should "throw exceptions on bad load paths" do
      end

      should "allow bad paths with appropriate option" do
      end

      should "exclude root with that option" do
      end

      should "raise an error with a bad option" do
      end
    end
  end
end
