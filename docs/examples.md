# Examples

Real-world examples of using ActionAudit in different scenarios and applications.

## Basic Examples

### Simple User Management

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  include ActionAudit

  def create
    @user = User.create!(user_params)
    redirect_to @user, notice: 'User created successfully'
  end

  def update
    @user = User.find(params[:id])
    @user.update!(user_params)
    redirect_to @user, notice: 'User updated successfully'
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy!
    redirect_to users_path, notice: 'User deleted successfully'
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
```

```yaml
# config/audit.yml
users:
  create: "Created user %{email} with role %{role}"
  update: "Updated user %{id} - %{name}"
  destroy: "Deleted user %{id}"
```

**Log Output:**
```
users/create - Created user john@example.com with role admin
users/update - Updated user 123 - John Smith
users/destroy - Deleted user 123
```

## Advanced Examples

### Multi-Level Admin Interface

```ruby
# app/controllers/admin/users_controller.rb
class Admin::UsersController < ApplicationController
  include ActionAudit
  before_action :require_admin

  def create
    @user = User.create!(user_params)
    @user.send_welcome_email if params[:send_welcome]
    redirect_to admin_user_path(@user)
  end

  def activate
    @user = User.find(params[:id])
    @user.update!(active: true, activated_at: Time.current)
    redirect_to admin_user_path(@user)
  end

  def impersonate
    @user = User.find(params[:id])
    session[:impersonated_user_id] = @user.id
    redirect_to root_path
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role, :department)
  end
end
```

```yaml
# config/audit.yml
admin:
  users:
    create: "Admin created user %{email} in %{department} department"
    update: "Admin updated user %{id}"
    destroy: "Admin deleted user %{id}"
    activate: "Admin activated user %{id}"
    deactivate: "Admin deactivated user %{id}"
    impersonate: "Admin impersonated user %{id}"
```

### API Endpoints with Detailed Logging

```ruby
# app/controllers/api/v1/webhooks_controller.rb
class API::V1::WebhooksController < ApplicationController
  include ActionAudit
  skip_before_action :verify_authenticity_token
  before_action :set_audit_context

  def create
    @webhook = WebhookEvent.create!(webhook_params)
    WebhookProcessor.perform_async(@webhook.id)
    render json: { status: 'received', id: @webhook.id }
  end

  private

  def webhook_params
    params.permit(:source, :event_type, :payload).tap do |wp|
      wp[:payload_size] = params[:payload].to_s.bytesize
      wp[:client_ip] = request.remote_ip
    end
  end

  def set_audit_context
    # Add context for auditing
    params[:source] = request.headers['X-Webhook-Source'] || 'unknown'
    params[:user_agent] = request.user_agent
  end
end
```

```yaml
# config/audit.yml
api:
  v1:
    webhooks:
      create: "Webhook received from %{source} - %{event_type} (%{payload_size} bytes) from %{client_ip}"
```

## E-commerce Examples

### Order Management

```ruby
# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  include ActionAudit
  before_action :authenticate_user!
  before_action :set_audit_user_context

  def create
    @order = current_user.orders.build(order_params)
    @order.calculate_totals!
    @order.save!

    redirect_to @order, notice: 'Order placed successfully'
  end

  def cancel
    @order = current_user.orders.find(params[:id])
    @order.cancel!

    redirect_to @order, notice: 'Order cancelled'
  end

  def refund
    @order = Order.find(params[:id])
    @refund = @order.create_refund!(refund_amount: params[:amount])

    redirect_to @order, notice: 'Refund processed'
  end

  private

  def order_params
    params.require(:order).permit(:shipping_address, line_items: [:product_id, :quantity])
  end

  def set_audit_user_context
    params[:user_id] = current_user.id
    params[:user_email] = current_user.email
  end
end
```

```yaml
# config/audit.yml
orders:
  create: "User %{user_email} placed order %{id} for $%{total}"
  cancel: "User %{user_email} cancelled order %{id}"
  refund: "Refunded $%{amount} for order %{id} to user %{user_email}"
```

### Inventory Management

```ruby
# app/controllers/admin/inventory_controller.rb
class Admin::InventoryController < ApplicationController
  include ActionAudit
  before_action :require_inventory_manager

  def adjust
    @product = Product.find(params[:id])
    old_quantity = @product.inventory_quantity
    @product.update!(inventory_quantity: params[:new_quantity])

    params[:old_quantity] = old_quantity
    params[:adjustment] = params[:new_quantity].to_i - old_quantity
    params[:product_name] = @product.name

    redirect_to admin_product_path(@product)
  end

  def restock
    @product = Product.find(params[:id])
    @product.increment!(:inventory_quantity, params[:quantity].to_i)

    params[:product_name] = @product.name

    redirect_to admin_product_path(@product)
  end
end
```

```yaml
# config/audit.yml
admin:
  inventory:
    adjust: "Inventory adjusted for %{product_name}: %{old_quantity} → %{new_quantity} (Δ%{adjustment})"
    restock: "Restocked %{product_name} with %{quantity} units"
```

## Authentication & Security Examples

### Session Management

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  include ActionAudit
  before_action :set_audit_context, except: [:new]

  def create
    @user = User.find_by(email: params[:email])

    if @user&.authenticate(params[:password])
      if @user.active?
        session[:user_id] = @user.id
        params[:login_method] = 'password'
        redirect_to dashboard_path
      else
        params[:failure_reason] = 'account_inactive'
        redirect_to login_path, alert: 'Account is inactive'
      end
    else
      params[:failure_reason] = 'invalid_credentials'
      redirect_to login_path, alert: 'Invalid credentials'
    end
  end

  def destroy
    params[:session_duration] = time_since_login
    session.clear
    redirect_to root_path
  end

  private

  def set_audit_context
    params[:ip_address] = request.remote_ip
    params[:user_agent] = request.user_agent&.truncate(100)
  end

  def time_since_login
    return 'unknown' unless session[:login_time]
    Time.current - Time.parse(session[:login_time])
  end
end
```

```yaml
# config/audit.yml
sessions:
  create: "Login %{email} via %{login_method} from %{ip_address} - %{user_agent}"
  destroy: "Logout %{email} after %{session_duration} seconds"

# For failed attempts, you might have:
login_failures:
  create: "Failed login attempt for %{email}: %{failure_reason} from %{ip_address}"
```

### Password Management

```ruby
# app/controllers/passwords_controller.rb
class PasswordsController < ApplicationController
  include ActionAudit
  before_action :authenticate_user!, except: [:forgot, :reset]

  def forgot
    @user = User.find_by(email: params[:email])
    if @user
      @user.generate_reset_token!
      PasswordMailer.reset_instructions(@user).deliver_now
      params[:user_id] = @user.id
    end

    redirect_to login_path, notice: 'Reset instructions sent if email exists'
  end

  def reset
    @user = User.find_by(reset_token: params[:token])
    if @user&.reset_token_valid?
      @user.update!(password: params[:password], reset_token: nil)
      params[:user_id] = @user.id
      redirect_to login_path, notice: 'Password reset successfully'
    else
      redirect_to forgot_password_path, alert: 'Invalid or expired token'
    end
  end

  def change
    if current_user.authenticate(params[:current_password])
      current_user.update!(password: params[:new_password])
      params[:user_id] = current_user.id
      redirect_to profile_path, notice: 'Password changed successfully'
    else
      redirect_to change_password_path, alert: 'Current password is incorrect'
    end
  end
end
```

```yaml
# config/audit.yml
passwords:
  forgot: "Password reset requested for user %{user_id}"
  reset: "Password reset completed for user %{user_id}"
  change: "Password changed for user %{user_id}"
```

## Content Management Examples

### Blog Post Management

```ruby
# app/controllers/admin/posts_controller.rb
class Admin::PostsController < ApplicationController
  include ActionAudit
  before_action :authenticate_admin!

  def create
    @post = current_user.posts.build(post_params)
    @post.save!

    params[:author_name] = current_user.name

    redirect_to admin_post_path(@post)
  end

  def publish
    @post = Post.find(params[:id])
    @post.update!(published: true, published_at: Time.current)

    params[:title] = @post.title
    params[:author_name] = @post.author.name

    redirect_to admin_post_path(@post)
  end

  def feature
    @post = Post.find(params[:id])
    @post.update!(featured: true, featured_at: Time.current)

    params[:title] = @post.title

    redirect_to admin_post_path(@post)
  end

  private

  def post_params
    params.require(:post).permit(:title, :content, :category_id, :tags)
  end
end
```

```yaml
# config/audit.yml
admin:
  posts:
    create: "Created post '%{title}' by %{author_name}"
    update: "Updated post '%{title}'"
    destroy: "Deleted post '%{title}'"
    publish: "Published post '%{title}' by %{author_name}"
    unpublish: "Unpublished post '%{title}'"
    feature: "Featured post '%{title}'"
    unfeature: "Unfeatured post '%{title}'"
```

## Integration Examples

### Third-Party Service Integration

```ruby
# app/controllers/integrations/stripe_controller.rb
class Integrations::StripeController < ApplicationController
  include ActionAudit
  skip_before_action :verify_authenticity_token
  before_action :verify_stripe_signature
  before_action :set_audit_context

  def webhook
    case params[:type]
    when 'payment_intent.succeeded'
      handle_successful_payment
    when 'subscription.cancelled'
      handle_subscription_cancellation
    end

    render json: { received: true }
  end

  private

  def handle_successful_payment
    payment_intent = params[:data][:object]
    order = Order.find_by(stripe_payment_intent: payment_intent[:id])
    order&.mark_as_paid!

    params[:order_id] = order&.id
    params[:amount] = payment_intent[:amount]
  end

  def handle_subscription_cancellation
    subscription = params[:data][:object]
    user = User.find_by(stripe_subscription_id: subscription[:id])
    user&.cancel_subscription!

    params[:user_id] = user&.id
    params[:subscription_id] = subscription[:id]
  end

  def set_audit_context
    params[:webhook_id] = params[:id]
    params[:event_type] = params[:type]
    params[:stripe_account] = params[:account] if params[:account]
  end
end
```

```yaml
# config/audit.yml
integrations:
  stripe:
    webhook: "Stripe webhook %{webhook_id}: %{event_type} processed"
```

## Custom Formatting Examples

### JSON Structured Logging

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_formatter = lambda do |controller, action, message|
  {
    event_type: 'audit',
    timestamp: Time.current.iso8601,
    controller: controller,
    action: action,
    message: message,
    user_id: defined?(current_user) && current_user&.id,
    request_id: defined?(request) && request&.request_id,
    ip_address: defined?(request) && request&.remote_ip
  }.to_json
end
```

### Syslog Integration

```ruby
# config/initializers/action_audit.rb
require 'syslog/logger'

ActionAudit.log_formatter = lambda do |controller, action, message|
  # Format for syslog
  "AUDIT user_id=#{current_user&.id} controller=#{controller} action=#{action} message=\"#{message}\""
end

# Custom logger for audit messages
class AuditLogger
  def self.info(message)
    syslog = Syslog::Logger.new('rails_audit')
    syslog.info(message)
  end
end

# Override default Rails logger for audit messages
module ActionAudit
  private

  def audit_request
    # ... existing logic ...

    # Use custom logger instead of Rails.logger
    AuditLogger.info(formatted_message)
  end
end
```

### Slack Integration

```ruby
# config/initializers/action_audit.rb
ActionAudit.log_formatter = lambda do |controller, action, message|
  # Log to Rails logger
  Rails.logger.info("[AUDIT] #{controller}/#{action} - #{message}")

  # Also send critical actions to Slack
  if critical_action?(controller, action)
    SlackNotifier.ping(
      text: "🔒 Critical Action: #{message}",
      channel: '#security-alerts',
      username: 'AuditBot'
    )
  end

  "[AUDIT] #{controller}/#{action} - #{message}"
end

def critical_action?(controller, action)
  critical_patterns = [
    'admin/users/destroy',
    'admin/settings/update',
    'integrations/*/webhook'
  ]

  path = "#{controller}/#{action}"
  critical_patterns.any? { |pattern| File.fnmatch(pattern, path) }
end
```

## Testing Examples

### RSpec Controller Tests

```ruby
# spec/controllers/users_controller_spec.rb
RSpec.describe UsersController, type: :controller do
  describe '#create' do
    let(:user_params) { { name: 'John Doe', email: 'john@example.com' } }

    it 'creates a user and logs the action' do
      expect(Rails.logger).to receive(:info).with(/Created user john@example\.com/)

      post :create, params: { user: user_params }

      expect(response).to redirect_to(User.last)
      expect(User.last.email).to eq('john@example.com')
    end

    context 'with custom log formatter' do
      before do
        ActionAudit.log_formatter = ->(c, a, m) { "CUSTOM: #{c}/#{a} - #{m}" }
      end

      it 'uses custom formatting' do
        expect(Rails.logger).to receive(:info).with(/CUSTOM: users\/create - Created user/)

        post :create, params: { user: user_params }
      end
    end
  end
end
```

### Feature Tests

```ruby
# spec/features/admin_user_management_spec.rb
RSpec.feature 'Admin User Management', type: :feature do
  let(:admin) { create(:admin_user) }

  before { sign_in admin }

  scenario 'Admin creates a new user' do
    visit new_admin_user_path

    fill_in 'Email', with: 'newuser@example.com'
    fill_in 'Name', with: 'New User'
    select 'Editor', from: 'Role'

    expect {
      click_button 'Create User'
    }.to change(User, :count).by(1)

    # Check that audit log was created
    expect(Rails.logger).to have_received(:info).with(/Admin created user newuser@example\.com/)
  end
end
```

## Next Steps

- [Learn about troubleshooting](troubleshooting.md)
- [Check the API reference](api-reference.md)
- [See migration guide](migration.md)
