# typed: true
# frozen_string_literal: true

require "test_helper"
require_relative "support/expectations_test_runner"

class InlayHintsExpectationsTest < ExpectationsTestRunner
  expectations_tests RubyLsp::Requests::InlayHints, "inlay_hints"

  def run_expectations(source)
    params = @__params&.any? ? @__params : default_args
    uri = URI("file://#{@_path}")
    document = RubyLsp::RubyDocument.new(source: source, version: 1, uri: uri, global_state: @global_state)

    dispatcher = Prism::Dispatcher.new
    @global_state.apply_options({
      initializationOptions: {
        featuresConfiguration: {
          inlayHint: { implicitRescue: true, implicitHashValue: true },
        },
      },
    })
    request = RubyLsp::Requests::InlayHints.new(@global_state, document, dispatcher)
    dispatcher.dispatch(document.ast)
    range = params.first
    ruby_range = range.dig(:start, :line)..range.dig(:end, :line)

    request.perform.select do |hint|
      ruby_range.cover?(hint.position[:line])
    end
  end

  def default_args
    [{ start: { line: 0, character: 0 }, end: { line: 20, character: 20 } }]
  end

  def test_skip_implicit_hash_value
    uri = URI("file://foo.rb")
    document = RubyLsp::RubyDocument.new(uri: uri, source: <<~RUBY, version: 1, global_state: @global_state)
      {bar:, baz:}
    RUBY

    dispatcher = Prism::Dispatcher.new
    @global_state.apply_options({
      initializationOptions: {
        featuresConfiguration: {
          inlayHint: { implicitRescue: true, implicitHashValue: false },
        },
      },
    })
    request = RubyLsp::Requests::InlayHints.new(@global_state, document, dispatcher)
    dispatcher.dispatch(document.ast)
    assert_empty(request.perform)
  end

  def test_skip_implicit_rescue
    uri = URI("file://foo.rb")
    document = RubyLsp::RubyDocument.new(uri: uri, source: <<~RUBY, version: 1, global_state: @global_state)
      begin
      rescue
      end
    RUBY

    dispatcher = Prism::Dispatcher.new
    @global_state.apply_options({
      initializationOptions: {
        featuresConfiguration: {
          inlayHint: { implicitRescue: false, implicitHashValue: true },
        },
      },
    })
    request = RubyLsp::Requests::InlayHints.new(@global_state, document, dispatcher)
    dispatcher.dispatch(document.ast)
    assert_empty(request.perform)
  end
end
