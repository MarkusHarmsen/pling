require 'faraday'

module Pling
  module Gateway
    ##
    # Pling gateway to communicate with Google's Android C2DM service.
    #
    #
    # Example:
    #
    #   Pling::Gateway::C2DM.new({
    #     :email    => 'your-email@gmail.com', # Your google account's email address (Required)
    #     :password => 'your-password',        # Your google account's password (Required)
    #     :source   => 'your-app-name',        # Your applications source identifier (Required)
    #
    #     :authentication_url => 'http://...', # The authentication url to use (Optional, Default: C2DM default authentication url)
    #     :push_url           => 'http://...', # The push url to use (Optional, Default: C2DM default authentication url)
    #     :adapter            => :net_http,    # The Faraday adapter you want to use (Optional, Default: :net_http)
    #     :connection         => {}            # Options you want to pass to Faraday (Optional, Default: {})
    #   })
    class C2DM < Base

      attr_reader :token

      def initialize(configuration)
        setup_configuration(configuration, :require => [:email, :password, :source])
        authenticate!
      end

      def deliver(message, device)
        message = Pling._convert(message, :message)
        device  = Pling._convert(device,  :device)

        response = connection.post(configuration[:push_url], {
          :registration_id => device.identifier,
          :"data.content" => message.content
        }, { :Authorization => "GoogleLogin auth=#{@token}"})

        raise(Pling::DeliveryFailed, "C2DM Delivery failed: [#{response.status}] #{response.body}") unless response.success?
      end

      private

        def authenticate!
          response = connection.post(configuration[:authentication_url], {
            :accountType => 'HOSTED_OR_GOOGLE',
            :service     => 'ac2dm',
            :Email       => configuration[:email],
            :Passwd      => configuration[:password],
            :source      => configuration[:source]
          })

          raise(Pling::AuthenticationFailed, "C2DM Authentication failed: [#{response.status}] #{response.body}") unless response.success?

          @token = extract_token(response.body)
        end

        def default_configuration
          super.merge({
            :authentication_url => 'https://www.google.com/accounts/ClientLogin',
            :push_url           => 'https://android.apis.google.com/c2dm/send',
            :adapter            => :net_http,
            :connection         => {}
          })
        end

        def connection
          @connection ||= Faraday.new(configuration[:connection]) do |builder|
            builder.use Faraday::Request::UrlEncoded
            builder.use Faraday::Response::Logger if configuration[:debug]
            builder.adapter(configuration[:adapter])
          end
        end

        def extract_token(body)
          matches = body.match(/^Auth=(.+)$/)
          matches ? matches[1] : raise(Pling::AuthenticationFailed, "C2DM Token extraction failed")
        end
    end
  end
end
