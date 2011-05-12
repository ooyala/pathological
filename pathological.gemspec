Gem::Specification.new do |s|
  s.name = "pathological"
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">=0") if s.respond_to? :required_rubygems_version=
  s.specification_version = 2 if s.respond_to? :specification_version=

  s.authors = "Daniel MacDougall", "Caleb Spare"
  s.email = "dmac@ooyala.com", "caleb@ooyala.com"
  s.homepage = "http://www.ooyala.com"
  s.rubyforge_project = "pathological"

  s.summary = "A nice way to manage your project's require paths."
  s.description = <<-DESCRIPTION
    Pathological provides a way to manage a project's require paths by using a small config file that
    indicates all directories to include in the load path.
  DESCRIPTION

  s.files = %w[
    README.md
    LICENSE
    Rakefile
    pathological.gemspec
    lib/pathological.rb
    lib/pathological/base.rb
  ]
end
