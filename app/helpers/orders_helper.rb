module OrdersHelper
  # implement in your application
  def link_to_profile_for(user)
    link_to user.trolley_user_display_name, url_for_trolley(:user => user)
  end

  def link_to_orders_for(user)
    link_to(user.trolley_user_display_name, :user => user)
  end

  def can_delete_line_item?(order)
    order.state_ok_to_delete_line_item? &&
      (order.user != current_user &&
       order.in_process?) ||
      order.current?
  end

  # override the method can_trigger_...? methods with your own security checks
  def can_trigger_fulfilled_without_acceptance?
    params[:controller] == 'orders'
  end

  def can_trigger_finish?
    params[:controller] == 'orders'
  end

  def order_button_for(action, order, options = {})
    options = options.merge({ :confirm => t('orders.order.are_you_sure'),
                              :class => "order-button button-#{action}" })

    options[:method] = 'delete' if action.to_s == 'destroy'

    target_action = options.delete(:target_action) || action

    url_for_options = { :controller => :orders,
                :action => target_action,
                :id => order }

    url_for_options = url_for_options.merge(options.delete(:url_for_options)) if options[:url_for_options]

    button_to(t("orders.order.#{action}"),
              url_for_options,
              options)
  end

  # define button_to methods for each possible event name for Order
  Order.workflow_event_names.each do |event_name|
    code = lambda { |order|
      order_button_for(event_name.to_s, order)
    }

    define_method("button_to_#{event_name}", &code)
  end

  # special case
  def button_to_clear(order)
    order_button_for('destroy', order)
  end

  # single definition helper for format of displaying number of something
  def show_count_for(number)
    " (#{number})"
  end

  def link_to_state_unless_current(state, count)
    link_to_unless_current(t("orders.index.#{state}") + show_count_for(count),
                           :state => state,
                           :user => @user,
                           :trolley => @trolley,
                           :from => @from,
                           :until => @until)
  end

  def sorted_state_names
    Order.workflow_spec.state_names.sort_by { |s| I18n.t("orders.index.#{s.to_s}") }
  end

  # returns a list of links to order states
  # that have orders in their state
  # with number of orders in a given state indicated
  def state_links
    html = '<ul id="state-links" class="horizontal-list">'

    states_count = 1

    states = sorted_state_names

    states.each do |state|
      adjusted_conditions = adjust_value_in_conditions_for(:workflow_state, state.to_s, @conditions)

      with_state_count = Order.count(:conditions => adjusted_conditions)

      if with_state_count > 0
        classes = 'state-link'
        classes += ' first' if states_count == 1

        if state == :in_process && @state == state.to_s
          html += content_tag('li',
                              t("orders.index.#{state}") + show_count_for(with_state_count),
                              :class => classes)
        else
          html += content_tag('li',
                              link_to_state_unless_current(state, with_state_count),
                              :class => classes)
          
        end
        states_count += 1
      end
    end

    html += '</ul>'
  end

  def order_date_value(direction)
    return String.new unless @conditions

    new_conditions = drop_key_from_conditions(:from, @conditions)
    new_conditions = drop_key_from_conditions(:until, new_conditions)

    value = Order.find(:first,
                       :select => 'created_at',
                       :order => "created_at #{direction}",
                       :conditions => new_conditions)

    value.created_at.to_s(:db).split('\s')[0]
  end

  def oldest_order_value
    default_date_value('asc')
  end

  def newest_order_value
    default_date_value('desc')
  end

  def orders_state_headline
    html = t("orders.helpers.#{@state}_orders")
    
    if @from
      html += ' ' + t('orders.helpers.from') + ' '
      html += @from
    end
    
    if @until
      html += ' ' + t('orders.helpers.until') + ' '
      html += @until
    end

    if @user
      html += ' ' + t('orders.helpers.by') + ' '
      html += @user.trolley_user_display_name
    end

    html
  end

  def clear_extra_params
    if @user || @from || @until
      clear_link = link_to(t("orders.helpers.clear_params"),
                           :state => @state,
                           :user => nil,
                           :trolley => nil,
                           :from => nil,
                           :until => nil)

      clear_link = ' [ ' + clear_link + ' ]'
      content_tag('span', clear_link, :class => 'clear-params')
    end
  end

  private
  
  def adjust_value_in_conditions_for(key, value, conditions)
    new_conditions_hash = Hash.new
    if conditions.is_a?(Array)
      new_conditions_hash = conditions[1]
    else
      new_conditions_hash = conditions
    end

    new_conditions_hash.delete(:key)
    
    new_conditions_hash[key] = value unless value == nil

    new_conditions = conditions.is_a?(Array) ? [conditions[0], new_conditions_hash] : new_conditions_hash
  end

  def drop_key_from_conditions(key, conditions)
    adjust_value_in_conditions_for(key, nil, conditions)
  end

  def url_for_options_for_orders_index
    { :controller => 'orders', :action => 'index' }
  end

  def meta_data_for(order)
    html = '<div id="order-meta-data">'
    html += '<h3>' + t('orders.helpers.order_number') + " #{order.id}</h3>"
    html += '</div>'
  end

  # override this in your app to add your own fields at checkout
  def order_checkout_fields(form)
  end

  # order number
  # order user
  # number of line_items
  def link_to_as_summary_of(order, user = nil)
    link_text = t('orders.helpers.order_number') + " #{order.id}"
    link_text += " - #{user.trolley_user_display_name}" if user
    link_text += " - (#{order.line_items.size} #{t 'orders.helpers.items'})" if order.line_items.size > 0

    link_to(link_text, url_for_order(:order => order))
  end
  
  def checkout_form_target_action_url_hash
    {:action => 'checkout', :id => @order}
  end
end
