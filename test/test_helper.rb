# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

ENV["RUBY_LSP_ENV"] = "test"

if ENV["COVERAGE"]
  require "simplecov"

  SimpleCov.start do
    T.bind(self, SimpleCov::Configuration)
    enable_coverage :branch
  end
end

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
$VERBOSE = nil unless ENV["VERBOSE"] || ENV["CI"]

require "ruby_lsp/internal"
require "ruby_lsp/test_helper"
require "rubocop/cop/ruby_lsp/use_language_server_aliases"
require "rubocop/cop/ruby_lsp/use_register_with_handler_method"

require "minitest/autorun"
require "tempfile"
require "mocha/minitest"

# Do not require minitest-reporters when running tests via the Ruby LSP's test explorer. Invoking
# `Minitest::Reporters.use!` overrides our reporter customizations and breaks the integrations.
#
# We also don't need debug related things
unless ENV["RUBY_LSP_TEST_RUNNER"] == "true"
  SORBET_PATHS = Gem.loaded_specs["sorbet-runtime"].full_require_paths.freeze #: Array[String]

  # Define breakpoint methods without actually activating the debugger
  require "debug/prelude"
  # Load the debugger configuration to skip Sorbet paths. But this still doesn't activate the debugger
  require "debug/config"
  DEBUGGER__::CONFIG[:skip_path] = Array(DEBUGGER__::CONFIG[:skip_path]) + SORBET_PATHS

  require "minitest/reporters"
  minitest_reporter = if ENV["SPEC_REPORTER"]
    Minitest::Reporters::SpecReporter.new(color: true)
  else
    Minitest::Reporters::DefaultReporter.new(color: true)
  end

  Minitest::Reporters.use!(minitest_reporter)
end

module Minitest
  class Test
    include RubyLsp::TestHelper

    Minitest::Test.make_my_diffs_pretty!

    #: (IO output) -> Array[Hash[String, untyped]]
    def parse_json_api_stream(output)
      output.each_line("\r\n\r\n").map do |headers|
        content_length = headers[/Content-Length: (\d+)/i, 1]
        raise "Error reading response" unless content_length

        data = output.read(Integer(content_length))
        JSON.parse(T.must(data))
      end
    end
  end
end

begin
  require "spoom/backtrace_filter/minitest"
  Minitest.backtrace_filter = Spoom::BacktraceFilter::Minitest.new
rescue LoadError
  # Tapioca (and thus Spoom) is not available on Windows
end
