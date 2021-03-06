# frozen_string_literal: true

module WorkSurfer
  class Client
    OPTIONS_WITH_CLASS_DEFAULT = [
      :api_key,
      :connection_builder,
      :connection_options,
      :default_headers,
      :default_territory_id,
      :url_base,
    ].freeze

    OPTIONS_WITH_CLASS_DEFAULT.each do |option|
      define_singleton_method(option) do
        instance_variable_get("@#{option}")
      end

      define_singleton_method("#{option}=") do |*args|
        instance_variable_set("@#{option}", *args)
      end

      define_method(option) do
        instance_variable_get("@#{option}")
      end

      define_method("#{option}=") do |*args|
        instance_variable_set("@#{option}", *args)
      end
    end

    self.connection_builder = ->(builder) {
      builder.adapter   Faraday.default_adapter
      builder.request   :json
      builder.response  :json
    }

    self.connection_options = {}
    self.default_headers = {
      "X-WorkWave-Key": proc { api_key },
    }
    self.url_base = "https://wwrm.workwave.com/api/v1/"

    [
      :delete,
      :get,
      :post,
      :put,
    ].each do |http_verb|
      define_method(http_verb) do |*args|
        connection.public_send(http_verb, *args)
      end
    end

    def initialize(**options)
      unknown_options = options.keys - OPTIONS_WITH_CLASS_DEFAULT
      raise ArgumentError, "Unknown option key(s): #{unknown_options.join(", ")}. Valid options are: #{OPTIONS_WITH_CLASS_DEFAULT.join(", ")}." if unknown_options.any?

      OPTIONS_WITH_CLASS_DEFAULT.each do |option|
        value = options[option].nil? ? self.class.public_send(option) : options[option]
        public_send("#{option}=", value)
      end

      self
    end

    protected

    def connection
      @connection ||= Faraday::Connection.new(
        url_base,
        connection_options.merge(
          headers: evaluate_hash_values(default_headers)
        ),
        &connection_builder
      )
    end

    def evaluate_hash_values(hash)
      Hash[
        *hash.collect do |k, v|
          [
            k,
            v.is_a?(Proc) ? instance_eval(&v) : v,
          ]
        end.flatten
      ]
    end

    class << self
      def default_client
        @default_client ||= new
      end

      def default_client=(client)
        @default_client = client
      end
    end
  end
end
