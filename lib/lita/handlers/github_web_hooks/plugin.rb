module Lita
  module Handlers
    module GitHubWebHooks
      class Plugin < Handler
        def self.default_config(config)
          config.room_ids = []
        end

        # Overrides the handler config key, from plugin to github_web_hooks.
        def self.name
          "GithubWebHooks"
        end

        http.post "/github-webhooks", :receive_hook

        def receive_hook(request, response)
          if valid?(request)
            event_class = event_class_from_request(request)
            payload = extract_payload(request)
            event_class.new(robot, payload).call
          end

          response.status = 202
        rescue => ex
          Lita.logger.fatal(ex.message)
          Lita.logger.fatal(ex.backtrace)
        end

        private

        def event_class_from_request(request)
          GitHubWebHooks.hooks[request.env["HTTP_X_GITHUB_EVENT"]]
        end

        def extract_payload(request)
          MultiJson.load(request.body)
        end

        def github_cidrs
          response = http.get("https://api.github.com/meta")
          data = MultiJson.load(response.body)
          data["hooks"]
        end

        def valid?(request)
          valid_content_type?(request) && valid_event_type?(request) && valid_ip?(request)
        end

        def valid_content_type?(request)
          request.media_type == "application/json"
        end

        def valid_event_type?(request)
          !event_class_from_request(request).nil?
        end

        def valid_ip?(request)
          ip = request.env["REMOTE_ADDR"]

          github_cidrs.any? do |cidr|
            NetAddr::CIDR.create(cidr).contains?(ip)
          end
        end
      end

      Lita.register_handler(Plugin)
    end
  end
end
