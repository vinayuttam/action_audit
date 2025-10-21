# Troubleshooting Guide

Common issues and solutions when using ActionAudit.

## Installation Issues

### Gem Not Loading

**Problem:** ActionAudit module is not available after installation.

**Symptoms:**
```ruby
NameError: uninitialized constant ActionAudit
```

**Solutions:**
1. **Check Gemfile:** Ensure ActionAudit is properly added to your Gemfile:
   ```ruby
   gem 'action_audit'
   ```

2. **Run bundle install:** Make sure you've installed the gem:
   ```bash
   bundle install
   ```

3. **Restart Rails server:** Some changes require a server restart:
   ```bash
   rails server
   ```

4. **Check Rails version compatibility:** ActionAudit requires Rails 6.0+:
   ```bash
   rails --version
   ```

### Generator Not Found

**Problem:** Rails generator is not available.

**Symptoms:**
```bash
Could not find generator 'action_audit:install'
```

**Solutions:**
1. **Restart Rails console/server:** Generators are loaded at startup
2. **Check gem installation:** Verify ActionAudit is properly installed:
   ```bash
   bundle show action_audit
   ```
3. **Run from Rails root:** Ensure you're in the Rails application directory

## Configuration Issues

### Audit Messages Not Loading

**Problem:** Audit messages from `config/audit.yml` are not being loaded.

**Symptoms:**
- No audit logs appearing
- `ActionAudit::AuditMessages.lookup` returns `nil`

**Debugging Steps:**

1. **Check file existence:**
   ```bash
   ls -la config/audit.yml
   ```

2. **Verify YAML syntax:**
   ```bash
   ruby -e "require 'yaml'; puts YAML.load_file('config/audit.yml')"
   ```

3. **Check Rails console:**
   ```ruby
   # In Rails console
   ActionAudit::AuditMessages.messages
   # Should show your loaded messages

   ActionAudit::AuditMessages.lookup("users", "create")
   # Should return your configured message
   ```

**Common Solutions:**
- **Fix YAML syntax:** Ensure proper indentation and no tabs
- **Restart server:** Configuration is loaded at startup
- **Check file permissions:** Ensure Rails can read the file

### Invalid YAML Syntax

**Problem:** YAML file has syntax errors.

**Symptoms:**
```
YAML syntax error in config/audit.yml
```

**Common YAML Issues:**

1. **Tabs instead of spaces:**
   ```yaml
   # Wrong (using tabs)
   users:
   	create: "Created user"

   # Correct (using spaces)
   users:
     create: "Created user"
   ```

2. **Inconsistent indentation:**
   ```yaml
   # Wrong
   users:
     create: "Created user"
       update: "Updated user"  # Too much indentation

   # Correct
   users:
     create: "Created user"
     update: "Updated user"
   ```

3. **Missing quotes for special characters:**
   ```yaml
   # Wrong
   users:
     create: Message with: colons

   # Correct
   users:
     create: "Message with: colons"
   ```

**YAML Validation:**
```bash
# Validate YAML syntax
ruby -e "require 'yaml'; YAML.load_file('config/audit.yml'); puts 'Valid YAML'"
```

## Runtime Issues

### No Audit Logs Appearing

**Problem:** Controllers are not logging audit messages.

**Symptoms:**
- Actions execute normally
- No audit logs in Rails logs
- No errors thrown

**Debugging Checklist:**

1. **Check ActionAudit inclusion:**
   ```ruby
   # In your controller
   class UsersController < ApplicationController
     include ActionAudit  # Make sure this is present
   end
   ```

2. **Verify message configuration:**
   ```ruby
   # Rails console
   ActionAudit::AuditMessages.lookup("users", "create")
   # Should return your configured message, not nil
   ```

3. **Check controller/action mapping:**
   ```ruby
   # For Admin::UsersController, action 'create'
   ActionAudit::AuditMessages.lookup("admin/users", "create")
   ```

4. **Test logger directly:**
   ```ruby
   # Rails console
   Rails.logger.info("Test message")
   # Should appear in logs
   ```

### Parameter Interpolation Not Working

**Problem:** Audit messages show `%{param}` instead of actual values.

**Symptoms:**
```
users/create - Created user %{email}  # email not interpolated
```

**Common Causes:**

1. **Parameter not in params:**
   ```ruby
   # Controller action
   def create
     # If params doesn't contain :email, interpolation fails
   end
   ```

2. **Wrong parameter name in audit.yml:**
   ```yaml
   # audit.yml has %{email} but controller has params[:user_email]
   users:
     create: "Created user %{email}"  # Should be %{user_email}
   ```

**Debugging:**
```ruby
# In controller action, add debugging
def create
  Rails.logger.debug "Params for audit: #{params.inspect}"
  # ... rest of action
end
```

### Error Messages in Logs

**Problem:** Seeing interpolation error messages in logs.

**Symptoms:**
```
Created user %{email} (interpolation error: key{email} not found)
```

**Solutions:**

1. **Add missing parameters:**
   ```ruby
   def create
     @user = User.create!(user_params)
     # Ensure email is available for auditing
     params[:email] = @user.email
   end
   ```

2. **Update audit message:**
   ```yaml
   # Use parameters that are always available
   users:
     create: "Created user with ID %{id}"  # id is usually available
   ```

3. **Use conditional parameters:**
   ```yaml
   users:
     create: "Created user %{id}"  # Simpler, always works
   ```

## Multi-Engine Issues

### Engine Configurations Not Loading

**Problem:** Audit messages from Rails engines are not being loaded.

**Symptoms:**
- Main app audit messages work
- Engine-specific messages don't work

**Debugging Steps:**

1. **Check engine structure:**
   ```
   engines/my_engine/
   ├── config/
   │   └── audit.yml    # Should exist
   └── lib/
       └── my_engine.rb
   ```

2. **Verify engine mounting:**
   ```ruby
   # In main app's routes.rb or engine mounting
   mount MyEngine::Engine, at: '/my_engine'
   ```

3. **Check Rails console:**
   ```ruby
   # List all engines
   Rails.application.railties.each do |railtie|
     puts railtie.class.name if railtie.respond_to?(:root)
   end
   ```

4. **Test individual engine loading:**
   ```ruby
   # Rails console
   ActionAudit::AuditMessages.load_from_file('engines/my_engine/config/audit.yml')
   ActionAudit::AuditMessages.lookup("my_engine/users", "create")
   ```

### Configuration Conflicts

**Problem:** Multiple engines define the same audit paths.

**Symptoms:**
- Unexpected audit messages
- Later engines override earlier ones

**Example Conflict:**
```yaml
# Engine A: config/audit.yml
users:
  create: "Engine A created user"

# Engine B: config/audit.yml
users:
  create: "Engine B created user"  # This overwrites Engine A
```

**Solutions:**

1. **Use namespaced paths:**
   ```yaml
   # Engine A
   engine_a:
     users:
       create: "Engine A created user"

   # Engine B
   engine_b:
     users:
       create: "Engine B created user"
   ```

2. **Check loading order:**
   ```ruby
   # Rails console - see load order
   Rails.application.railties.each_with_index do |railtie, index|
     puts "#{index}: #{railtie.class.name}" if railtie.respond_to?(:config)
   end
   ```

## Performance Issues

### Slow Application Startup

**Problem:** Application takes longer to start after adding ActionAudit.

**Symptoms:**
- Increased Rails startup time
- Many audit.yml files being loaded

**Solutions:**

1. **Optimize YAML files:**
   - Remove unused audit messages
   - Combine related messages
   - Use simpler message templates

2. **Profile loading:**
   ```ruby
   # Add to config/initializers/action_audit.rb
   Rails.logger.info "Loading ActionAudit configurations..."
   start_time = Time.current

   ActionAudit::AuditMessages.load_from_engines

   load_time = Time.current - start_time
   Rails.logger.info "ActionAudit loaded in #{load_time}s"
   ```

### Memory Usage

**Problem:** High memory usage from audit messages.

**Symptoms:**
- Increased Rails memory usage
- Large audit.yml files

**Solutions:**

1. **Reduce message complexity:**
   ```yaml
   # Instead of long descriptive messages
   users:
     create: "Created user %{email} with full name %{first_name} %{last_name} in department %{department} with role %{role} at %{created_at}"

   # Use simpler messages
   users:
     create: "Created user %{email}"
   ```

2. **Remove unused messages:**
   - Audit only important actions
   - Remove debug/development messages in production

## Development Issues

### Configuration Not Reloading

**Problem:** Changes to audit.yml don't take effect in development.

**Symptoms:**
- Modified audit messages don't appear
- Need to restart server for changes

**Solutions:**

1. **Check Rails development configuration:**
   ```ruby
   # config/environments/development.rb
   config.cache_classes = false  # Should be false
   ```

2. **Manual reload in console:**
   ```ruby
   # Rails console
   ActionAudit::AuditMessages.clear!
   ActionAudit::AuditMessages.load_from_engines
   ```

3. **Restart Rails server:**
   ```bash
   # Sometimes necessary for engine changes
   rails server
   ```

### Testing Issues

**Problem:** Audit messages interfere with tests.

**Symptoms:**
- Unexpected log output in tests
- Test failures due to audit logging

**Solutions:**

1. **Configure test environment:**
   ```ruby
   # config/environments/test.rb
   config.log_level = :warn  # Reduce log noise
   ```

2. **Disable auditing in tests:**
   ```ruby
   # spec/rails_helper.rb or test_helper.rb
   ActionAudit.log_formatter = nil
   ActionAudit.log_tag = nil
   ```

3. **Stub audit methods:**
   ```ruby
   # In specific tests
   before do
     allow_any_instance_of(ApplicationController).to receive(:audit_request)
   end
   ```

## Debugging Tools

### Enable Debug Logging

```ruby
# config/initializers/action_audit.rb
if Rails.env.development?
  ActionAudit.log_formatter = lambda do |controller, action, message|
    debug_info = {
      timestamp: Time.current.iso8601,
      controller: controller,
      action: action,
      message: message,
      params_keys: defined?(params) ? params.keys : 'N/A'
    }

    Rails.logger.debug "ActionAudit Debug: #{debug_info.inspect}"
    "[DEBUG] #{controller}/#{action} - #{message}"
  end
end
```

### Console Helpers

```ruby
# Add to config/initializers/action_audit.rb
if Rails.env.development?
  module ActionAuditHelpers
    def aa_messages
      ActionAudit::AuditMessages.messages
    end

    def aa_lookup(controller, action)
      ActionAudit::AuditMessages.lookup(controller, action)
    end

    def aa_reload
      ActionAudit::AuditMessages.clear!
      ActionAudit::AuditMessages.load_from_engines
      "ActionAudit messages reloaded"
    end
  end

  Rails.console do
    include ActionAuditHelpers
  end
end
```

### Test Audit Configuration

```ruby
# Create a test script: test_audit_config.rb
require_relative 'config/environment'

puts "Testing ActionAudit Configuration"
puts "=" * 40

# Test message loading
messages = ActionAudit::AuditMessages.messages
puts "Loaded #{messages.size} top-level message groups"

# Test specific lookups
test_cases = [
  ['users', 'create'],
  ['admin/users', 'create'],
  ['sessions', 'destroy']
]

test_cases.each do |controller, action|
  message = ActionAudit::AuditMessages.lookup(controller, action)
  status = message ? "✓" : "✗"
  puts "#{status} #{controller}/#{action}: #{message || 'NOT FOUND'}"
end

# Test parameter interpolation
test_message = "Created user %{email} with role %{role}"
test_params = { email: 'test@example.com', role: 'admin' }

begin
  interpolated = test_message % test_params.symbolize_keys
  puts "✓ Interpolation test: #{interpolated}"
rescue => e
  puts "✗ Interpolation failed: #{e.message}"
end
```

Run with: `ruby test_audit_config.rb`

## Getting Help

If you're still experiencing issues:

1. **Check the logs:** Enable debug logging and examine Rails logs
2. **Review configuration:** Use the debugging tools above
3. **Create minimal reproduction:** Strip down to simplest failing case
4. **Check GitHub issues:** Search for similar problems
5. **Open an issue:** Provide full error messages and configuration

## Common Error Messages

### `uninitialized constant ActionAudit`
- **Cause:** Gem not properly installed or loaded
- **Solution:** Check Gemfile, run `bundle install`, restart server

### `undefined method 'audit_request'`
- **Cause:** ActionAudit not included in controller
- **Solution:** Add `include ActionAudit` to controller

### `YAML syntax error`
- **Cause:** Invalid YAML in audit.yml file
- **Solution:** Validate YAML syntax, fix indentation issues

### `key{param} not found`
- **Cause:** Parameter referenced in audit message not available in controller params
- **Solution:** Ensure parameter exists or update audit message

### `undefined method 'tagged'`
- **Cause:** Logger doesn't support tagging (rare)
- **Solution:** Set `ActionAudit.log_tag = nil` or use custom logger

## Next Steps

- [Check the API reference](api-reference.md)
- [See migration guide](migration.md)
- [Return to main documentation](README.md)
