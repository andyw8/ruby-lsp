# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Listeners
    class InlayHints
      include Requests::Support::Common

      RESCUE_STRING_LENGTH = "rescue".length #: Integer

      #: (ResponseBuilders::CollectionResponseBuilder[Interface::InlayHint] response_builder, RequestConfig hints_configuration, Prism::Dispatcher dispatcher) -> void
      def initialize(response_builder, hints_configuration, dispatcher)
        @response_builder = response_builder
        @hints_configuration = hints_configuration
        @visibility_stack = [RubyIndexer::VisibilityScope.public_scope] #: Array[RubyIndexer::VisibilityScope]

        dispatcher.register(
          self,
          :on_rescue_node_enter,
          :on_implicit_node_enter,
          :on_def_node_enter,
          :on_call_node_enter,
          :on_call_node_leave,
        )
      end

      #: (Prism::RescueNode node) -> void
      def on_rescue_node_enter(node)
        return unless @hints_configuration.enabled?(:implicitRescue)
        return unless node.exceptions.empty?

        loc = node.location

        @response_builder << Interface::InlayHint.new(
          position: { line: loc.start_line - 1, character: loc.start_column + RESCUE_STRING_LENGTH },
          label: "StandardError",
          padding_left: true,
          tooltip: "StandardError is implied in a bare rescue",
        )
      end

      #: (Prism::ImplicitNode node) -> void
      def on_implicit_node_enter(node)
        return unless @hints_configuration.enabled?(:implicitHashValue)

        node_value = node.value
        loc = node.location
        tooltip = ""
        node_name = ""
        case node_value
        when Prism::CallNode
          node_name = node_value.name
          tooltip = "This is a method call. Method name: #{node_name}"
        when Prism::ConstantReadNode
          node_name = node_value.name
          tooltip = "This is a constant: #{node_name}"
        when Prism::LocalVariableReadNode
          node_name = node_value.name
          tooltip = "This is a local variable: #{node_name}"
        end

        @response_builder << Interface::InlayHint.new(
          position: { line: loc.start_line - 1, character: loc.start_column + node_name.length + 1 },
          label: node_name,
          padding_left: true,
          tooltip: tooltip,
        )
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_enter(node)
        # Track visibility method calls (private, protected, public)
        name = node.name.to_s
        return unless name == "private" || name == "protected" || name == "public"

        visibility = case name
        when "public"    then "x1" # RubyIndexer::Entry::Visibility::PUBLIC
        when "protected" then RubyIndexer::Entry::Visibility::PROTECTED
        when "private"   then RubyIndexer::Entry::Visibility::PRIVATE
        else
          RubyIndexer::Entry::Visibility::PUBLIC # Default case, shouldn't happen
        end

        # If there are arguments, it's specifying methods to change, not entering a visibility context
        if node.arguments&.arguments&.any?
          # No change to visibility stack needed for specific method visibility changes
          return
        end

        # No arguments means we're entering a new visibility context
        @visibility_stack.push(RubyIndexer::VisibilityScope.new(visibility: visibility))
      end

      #: (Prism::CallNode node) -> void
      def on_call_node_leave(node)
        # Pop visibility stack when leaving a visibility modifier section
        name = node.name.to_s
        return unless name == "private" || name == "protected" || name == "public"

        # If there are arguments and the first is a def node, we need to pop
        # e.g., `private def foo; end`
        if node.arguments&.arguments&.first&.is_a?(Prism::DefNode)
          @visibility_stack.pop
        end
      end

      #: (Prism::DefNode node) -> void
      def on_def_node_enter(node)
        # return unless @hints_configuration.enabled?(:methodDefinition)

        loc = node.location
        method_name = node.name
        current_visibility = current_visibility_scope.visibility.to_s.downcase

        @response_builder << Interface::InlayHint.new(
          position: { line: loc.start_line - 1, character: loc.start_column },
          label: current_visibility,
          padding_right: true,
          tooltip: "Method visibility: #{current_visibility}",
        )
      end

      private

      #: -> RubyIndexer::VisibilityScope
      def current_visibility_scope
        # T.must ensures the stack is never empty
        T.must(@visibility_stack.last)
      end
    end
  end
end
