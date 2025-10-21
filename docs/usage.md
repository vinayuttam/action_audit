# Usage Guide

This guide covers how to use ActionAudit in your Rails controllers and common usage patterns.

## Basic Usage

### Including ActionAudit

Include the `ActionAudit` module in any controller you want to audit:

```ruby
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    # ActionAudit automatically logs this action after completion
  end

  def update
    @user = User.find(params[:id])
    @user.update!(user_params)
    # Will log with interpolated parameters
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
```

### How It Works

1. **Automatic Hook**: When you include `ActionAudit`, it adds an `after_action :audit_request` callback
2. **Message Lookup**: After each action, it looks up the corresponding message in your `audit.yml` configuration
3. **Parameter Interpolation**: It interpolates the message with parameters from `params`
4. **Logging**: It logs the final message using `Rails.logger`

## Parameter Interpolation

ActionAudit uses Ruby's string interpolation (`%{key}`) to inject parameter values into audit messages.

### Basic Interpolation

```yaml
# config/audit.yml
users:
  create: "Created user %{email}"
  update: "Updated user %{id} with name %{name}"
```

```ruby
class UsersController < ApplicationController
  include ActionAudit

  def create
    # If params = { email: "john@example.com", name: "John Doe" }
    # Will log: "Created user john@example.com"
  end

  def update
    # If params = { id: "123", name: "Jane Doe" }
    # Will log: "Updated user 123 with name Jane Doe"
  end
end
```

### Nested Parameters

ActionAudit automatically flattens nested parameters for interpolation:

```ruby
# If params = { user: { email: "john@example.com" }, id: "123" }
# You can reference both %{id} and %{email} in your audit message
```

### Error Handling

If a parameter referenced in the audit message is missing, ActionAudit handles it gracefully:

```yaml
users:
  create: "Created user %{email} with role %{role}"
```

If `params[:role]` is missing, the log will show:
```
Created user john@example.com with role %{role} (interpolation error: key{role} not found)
```

## Controller Patterns

### Application-Wide Auditing

Include ActionAudit in your `ApplicationController` to audit all controller actions:

```ruby
class ApplicationController < ActionController::Base
  include ActionAudit

  # All controllers inheriting from this will be audited
end
```

### Selective Auditing

Include ActionAudit only in specific controllers:

```ruby
class Admin::UsersController < ApplicationController
  include ActionAudit  # Only admin actions are audited
end

class PublicController < ApplicationController
  # No auditing for public actions
end
```

### Namespaced Controllers

ActionAudit automatically handles namespaced controllers:

```ruby
class Admin::Users::ProfilesController < ApplicationController
  include ActionAudit

  def update
    # Will look up: admin/users/profiles/update in audit.yml
  end
end
```

## Common Usage Patterns

### User Management

```yaml
# config/audit.yml
admin:
  users:
    create: "Admin created user %{email} with role %{role}"
    update: "Admin updated user %{id}"
    destroy: "Admin deleted user %{id}"
    activate: "Admin activated user %{id}"
    deactivate: "Admin deactivated user %{id}"
```

```ruby
class Admin::UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    # Logs: "Admin created user john@example.com with role editor"
  end

  def activate
    @user = User.find(params[:id])
    @user.update!(active: true)
    # Logs: "Admin activated user 123"
  end
end
```

### Authentication & Sessions

```yaml
# config/audit.yml
sessions:
  create: "User logged in with %{email}"
  destroy: "User logged out"

passwords:
  create: "Password reset requested for %{email}"
  update: "Password changed for user %{user_id}"
```

```ruby
class SessionsController < ApplicationController
  include ActionAudit

  def create
    # params[:email] = "user@example.com"
    # Logs: "User logged in with user@example.com"
  end

  def destroy
    # Logs: "User logged out"
  end
end
```

### API Endpoints

```yaml
# config/audit.yml
api:
  v1:
    webhooks:
      create: "Webhook received from %{source} with %{event_type}"

    users:
      create: "API user created via client %{client_id}"
      update: "API user %{id} updated via client %{client_id}"
```

```ruby
class API::V1::WebhooksController < ApplicationController
  include ActionAudit

  def create
    # params = { source: "stripe", event_type: "payment.succeeded" }
    # Logs: "Webhook received from stripe with payment.succeeded"
  end
end
```

### Content Management

```yaml
# config/audit.yml
posts:
  create: "Created post '%{title}'"
  update: "Updated post %{id}"
  destroy: "Deleted post '%{title}'"
  publish: "Published post '%{title}'"
  unpublish: "Unpublished post '%{title}'"

categories:
  create: "Created category '%{name}'"
  update: "Updated category %{id} to '%{name}'"
  destroy: "Deleted category '%{name}'"
```

## Advanced Usage

### Custom Parameter Extraction

Sometimes you need to log information that's not directly in `params`. You can modify parameters before the audit:

```ruby
class PostsController < ApplicationController
  include ActionAudit

  before_action :set_audit_params, only: [:publish, :unpublish]

  def publish
    @post = Post.find(params[:id])
    @post.update!(published: true)
    # Will use the custom title parameter we set
  end

  private

  def set_audit_params
    @post = Post.find(params[:id])
    params[:title] = @post.title  # Add title to params for auditing
  end
end
```

### Conditional Auditing

You can conditionally include ActionAudit or skip certain actions:

```ruby
class UsersController < ApplicationController
  include ActionAudit

  # Skip auditing for certain actions
  skip_after_action :audit_request, only: [:show, :index]

  # Or use conditional logic
  def sensitive_action
    # Custom auditing logic here if needed
  end
end
```

### Integration with Current User

ActionAudit works well with authentication systems. The custom formatter can access `current_user`:

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_formatter = lambda do |controller, action, message|
  if defined?(current_user) && current_user
    "#{message} (by #{current_user.email})"
  else
    "#{message} (by anonymous user)"
  end
end
```

## Testing

### Testing Audit Messages

You can test that audit messages are being logged correctly:

```ruby
# spec/controllers/users_controller_spec.rb
RSpec.describe UsersController, type: :controller do
  describe "#create" do
    it "logs user creation" do
      expect(Rails.logger).to receive(:info).with(/Created user.*john@example\.com/)

      post :create, params: { user: { email: "john@example.com" } }
    end
  end
end
```

### Testing Without Auditing

In tests where you don't want audit logging, you can stub it:

```ruby
before do
  allow(controller).to receive(:audit_request)
end
```

## Performance Considerations

ActionAudit is designed to be lightweight:

- **Minimal Overhead**: Only runs after successful actions
- **Lazy Loading**: Audit messages are loaded once at startup
- **No Database Calls**: All auditing happens through Rails logger
- **Graceful Failures**: Missing messages or parameters won't break your application

## Error Handling

ActionAudit handles errors gracefully:

1. **Missing Messages**: If no audit message is configured for an action, nothing is logged
2. **Missing Parameters**: If interpolation fails, the error is logged alongside the original message
3. **Invalid YAML**: Rails will warn about YAML syntax errors during loading

## Next Steps

- [Learn about multi-engine setup](multi-engine.md)
- [See real-world examples](examples.md)
- [Check the API reference](api-reference.md)
