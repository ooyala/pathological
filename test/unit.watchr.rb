# Watchr script for unit tests

def run_test(test)
  system("bundle exec ruby #{test}")
end

watch(/^test\/.*_test\.rb/) { |md| run_test(md[0]) }
watch(/^lib\/(.*)\.rb/) { |md| run_test("test/#{md[1]}_test.rb") }

Signal.trap("INT") { abort("\n") }
