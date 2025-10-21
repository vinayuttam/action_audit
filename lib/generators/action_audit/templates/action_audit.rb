# ActionAudit configuration
# Customize how audit logs are formatted and tagged

# Add a tag to all audit log entries
# ActionAudit.log_tag = "AUDIT"

# Customize the log message format
# The formatter receives (controller_path, action_name, interpolated_message)
# ActionAudit.log_formatter = lambda do |controller, action, message|
#   user_info = defined?(current_user) && current_user ? "User: #{current_user.email}" : "User: anonymous"
#   "[#{Time.current.iso8601}] #{controller}/#{action} | #{message} | #{user_info}"
# end

# Simple formatter example:
# ActionAudit.log_formatter = ->(controller, action, msg) do
#   "AUDIT: #{controller}/#{action} - #{msg}"
# end
