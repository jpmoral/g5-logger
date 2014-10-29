module G5
  module Logger
    class Log
      Levels = %w(debug info warn error fatal unknown)

      class << self
        Levels.each do |name|
          define_method(name) do |attributes|
            log({level: name}.merge(attributes))
          end
        end

        def log(attributes)
          default_merge = {source_app_name: Config[:source_app_name]}.merge(attributes)
          log_level     = level(default_merge.delete(:level))
          Config[:logger].send(log_level, log_entry(default_merge))
        end

        def level(level)
          Levels.include?(level) ? level : :info
        end

        def log_entry(hash)
          scrubbed = redact hash.clone
          if  G5::Logger::KEY_VALUE_FORMAT== G5::Logger::Config[:format]
            scrubbed.keys.collect { |key| "#{key}=\"#{hash[key]}\"" }.join(", ")
          else
            scrubbed.to_json
          end
        end

        def log_json_req_resp(request, response, options={})
          options = options.merge(
              status:   response.try(:code),
              request:  request,
              response: response.try(:body))

          send(log_method(response.code), options)
        end

        def log_method(code)
          error = code > 299 rescue false
          error ? :error : :info
        end

        def redact(hash)
          hash.keys.each do |key|
            if hash[key].kind_of?(Hash)
              redact hash[key]
            elsif hash[key].kind_of?(Array)
              hash[key].each do |array_val|
                redact array_val if array_val.kind_of?(Hash)
              end
            else
              hash[key] = Config[:redact_value] if redactable?(key)
            end
          end
          hash
        end

        def redactable?(value)
          return false if value.blank?
          !!Config[:redact_keys].detect { |rk|
            if rk.class == String
              rk == value
            else
              value.match(rk)
            end
          }
        end
      end
    end
  end
end