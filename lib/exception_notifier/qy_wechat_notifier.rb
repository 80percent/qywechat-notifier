require 'exception_notification'
require 'qywechat/notifier'

module ExceptionNotifier
  class QyWechatNotifier < BaseNotifier
    def initialize(options)
      super
      @filter_exception = options[:filter_exception]
      @filter_exception = true if @filter_exception.nil?
    end

    def call(exception, options={})
      env = options[:env]

      if env.present?
        # 这里是外部请求导致的异常
        request = ActionDispatch::Request.new(env)
        request_items = {
          url: request.original_url,
          http_method: request.method,
          ip_address: request.remote_ip,
          parameters: request.filtered_parameters,
          timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S')
        }

        bt_msg = ''
        if @filter_exception
          bt_msg = %Q{Backtrace( Application Only, 5 below )>>>\n#{Rails.backtrace_cleaner.filter(exception.backtrace)[0..4].join("\n")}"}
        else
          bt_msg = %Q{Backtrace( 5 below )>>>\n#{exception.backtrace[0..4].join("\n")}}
        end

        message = <<~EOF
          Exception>>> #{exception.class.to_s}: #{exception.message.inspect}
          URL>>> #{request_items[:http_method]}: #{request_items[:url]} ( from: #{request_items[:ip_address]} )
          PARAM>>> #{request_items[:parameters]}
          Agent>>> #{request.filtered_env['HTTP_USER_AGENT']}
          Data>>> #{env && env['exception_notifier.exception_data']}
          ------------
          #{bt_msg}
        EOF

        Qywechat::Notifier::QyAPI.api_message.send_groupchat(message)
      else
        # 内部异常, 例如 sidekiq 任务
        message = <<-EOF
Exception>>> #{exception.class.to_s}: #{exception.message.inspect}
OPTIONS>>> \n
#{options.to_yaml}
------------
Backtrace( 5 below )>>>\n
#{exception.backtrace.to_a[0..4].join("\n")}
        EOF

        Qywechat::Notifier::QyAPI.api_message.send_groupchat(message)
      end
    end
  end
end
