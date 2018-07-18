# frozen_string_literal: true

# This is a monkey patch that back-ports a rails 5 feature
# adding the exception to the instrumentation payload

module ActiveSupport::Notifications
  class Instrumenter
    def instrument(name, payload = {})
      start name, payload
      begin
        yield payload
      rescue StandardError => e
        payload[:exception] = [e.class.name, e.message]
        payload[:exception_object] = e
        raise e
      ensure
        finish name, payload
      end
    end
  end
end
