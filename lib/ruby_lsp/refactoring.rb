# typed: strict
# frozen_string_literal: true

require "openai"
require "dotenv/load"

module RubyLsp
  class RefactoringResponse < OpenAI::BaseModel
    required :code, String, doc: "updated code"
    required :error, String, doc: "brief error message explaining what went wrong"
  end

  class Refactoring
    def simplify_conditional(code)
      content = <<~EOS
        Apply De Morgan's law to this snippet of Ruby code.
        If the code seems invalid then respond with an error.
        Response with only the code.

        ```ruby
        #{code}
        ```
      EOS
      response = client.responses.create(
        model: :"gpt-4.1",
        temperature: 0,
        input: [
          { role: "user", content: content },
        ],
        text: RefactoringResponse,
      )

      JSON.parse(response.output.first.content.first.to_json).fetch("parsed")
    end

    private

    def client
      @client ||= OpenAI::Client.new
    end
  end
end
