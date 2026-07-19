module Reports
  class SpendingDistributionQuery
    Node = Struct.new(
      :category,
      :parent_id,
      :current_amount_cents,
      :current_transactions_count,
      :previous_amount_cents,
      :previous_transactions_count,
      :direct_current_amount_cents,
      :direct_current_transactions_count,
      :direct_previous_amount_cents,
      :direct_previous_transactions_count,
      :children,
      keyword_init: true
    )

    DEFAULT_IMPACT_MODES = [ "normal" ].freeze
    EXCLUDED_IMPACT_MODES = %w[third_party informational].freeze

    def initialize(user:, params:, categories_scope: nil, today: Time.zone.today)
      @user = user
      @params = params
      @categories_scope = categories_scope
      @today = today.to_date
    end

    def call
      current = aggregate(expense_scope.where(occurred_on: current_period))
      previous = aggregate(expense_scope.where(occurred_on: comparison_period))
      categories = build_categories(current, previous)
      uncategorized = build_uncategorized(current, previous)
      category_entries = categories + (uncategorized ? [ uncategorized ] : [])

      {
        period: period_payload(current_period, partial: current_period_partial?),
        comparison_period: period_payload(comparison_period, partial: false),
        total_amount_cents: category_entries.sum { |entry| entry[:amount_cents] },
        transactions_count: category_entries.sum { |entry| entry[:transactions_count] },
        excluded: excluded_summary,
        categories: sort_entries(category_entries)
      }
    end

    private

    attr_reader :categories_scope, :params, :today, :user

    def filtered_transactions
      @filtered_transactions ||= Reports::FilteredTransactionsQuery.new(
        user: user,
        params: params,
        scope: user.transactions,
        use_month: false
      )
    end

    def expense_scope
      @expense_scope ||= filtered_transactions.call(
        apply_category_filter: false,
        apply_date_filter: false,
        impact_modes: selected_impact_modes
      ).where(transaction_type: "expense")
    end

    def excluded_summary
      EXCLUDED_IMPACT_MODES.index_with do |impact_mode|
        aggregate(
          filtered_transactions.call(
            apply_category_filter: false,
            apply_date_filter: false,
            impact_modes: [ impact_mode ]
          ).where(transaction_type: "expense", occurred_on: current_period)
        ).values.reduce({ amount_cents: 0, transactions_count: 0 }) do |totals, (amount_cents, transactions_count)|
          {
            amount_cents: totals[:amount_cents] + amount_cents,
            transactions_count: totals[:transactions_count] + transactions_count
          }
        end
      end
    end

    def aggregate(scope)
      scope.group(:category_id).pluck(
        :category_id,
        Arel.sql("COALESCE(SUM(transactions.amount_cents), 0)"),
        Arel.sql("COUNT(*)")
      ).to_h do |category_id, amount_cents, transactions_count|
        [ category_id, [ amount_cents.to_i, transactions_count.to_i ] ]
      end
    end

    def build_categories(current, previous)
      category_index = authorized_categories.index_by(&:id)
      nodes = {}
      known_category_ids = (current.keys + previous.keys).compact.uniq.select { |id| category_index.key?(id) }

      known_category_ids.each do |category_id|
        path = category_path(category_index.fetch(category_id), category_index)
        path.each_with_index do |path_category, index|
          nodes[path_category.id] ||= new_node(path_category, index.zero? ? nil : path[index - 1].id)
        end
      end

      known_category_ids.each do |category_id|
        assign_direct_amounts(nodes.fetch(category_id), current[category_id], previous[category_id])
      end

      nodes.each_value do |node|
        parent = nodes[node.parent_id]
        parent.children << node if parent
      end

      roots = nodes.values.select { |node| node.parent_id.nil? }
      roots.each { |root| roll_up!(root) }
      roots.map { |root| serialize_node(root) }
    end

    def authorized_categories
      @authorized_categories ||= (categories_scope || Category.where("user_id = ? OR (user_id IS NULL AND system = ?)", user.id, true)).to_a
    end

    def category_path(category, category_index)
      path = []
      seen_ids = []
      current = category

      loop do
        return [ category ] if seen_ids.include?(current.id)

        seen_ids << current.id
        path.unshift(current)
        break unless current.parent_id

        parent = category_index[current.parent_id]
        return [ category ] unless parent

        current = parent
      end

      path
    end

    def new_node(category, parent_id)
      Node.new(
        category: category,
        parent_id: parent_id,
        current_amount_cents: 0,
        current_transactions_count: 0,
        previous_amount_cents: 0,
        previous_transactions_count: 0,
        direct_current_amount_cents: 0,
        direct_current_transactions_count: 0,
        direct_previous_amount_cents: 0,
        direct_previous_transactions_count: 0,
        children: []
      )
    end

    def assign_direct_amounts(node, current_values, previous_values)
      node.direct_current_amount_cents, node.direct_current_transactions_count = current_values || [ 0, 0 ]
      node.direct_previous_amount_cents, node.direct_previous_transactions_count = previous_values || [ 0, 0 ]
      node.current_amount_cents = node.direct_current_amount_cents
      node.current_transactions_count = node.direct_current_transactions_count
      node.previous_amount_cents = node.direct_previous_amount_cents
      node.previous_transactions_count = node.direct_previous_transactions_count
    end

    def roll_up!(node)
      node.children.each do |child|
        roll_up!(child)
        node.current_amount_cents += child.current_amount_cents
        node.current_transactions_count += child.current_transactions_count
        node.previous_amount_cents += child.previous_amount_cents
        node.previous_transactions_count += child.previous_transactions_count
      end
    end

    def serialize_node(node)
      {
        key: "category:#{node.category.id}",
        category_id: node.category.id,
        parent_id: node.parent_id,
        name: node.category.name,
        color: node.category.color,
        amount_cents: node.current_amount_cents,
        transactions_count: node.current_transactions_count,
        previous_amount_cents: node.previous_amount_cents,
        previous_transactions_count: node.previous_transactions_count,
        direct_amount_cents: node.direct_current_amount_cents,
        direct_transactions_count: node.direct_current_transactions_count,
        direct_previous_amount_cents: node.direct_previous_amount_cents,
        direct_previous_transactions_count: node.direct_previous_transactions_count,
        children: sort_nodes(node.children).map { |child| serialize_node(child) }
      }
    end

    def build_uncategorized(current, previous)
      category_index = authorized_categories.index_by(&:id)
      current_values = combined_values(current, category_index)
      previous_values = combined_values(previous, category_index)
      return if current_values == [ 0, 0 ] && previous_values == [ 0, 0 ]

      {
        key: "uncategorized",
        category_id: nil,
        parent_id: nil,
        name: "Sem categoria",
        color: nil,
        amount_cents: current_values.first,
        transactions_count: current_values.last,
        previous_amount_cents: previous_values.first,
        previous_transactions_count: previous_values.last,
        direct_amount_cents: current_values.first,
        direct_transactions_count: current_values.last,
        direct_previous_amount_cents: previous_values.first,
        direct_previous_transactions_count: previous_values.last,
        children: []
      }
    end

    def combined_values(aggregates, category_index)
      aggregates.each_with_object([ 0, 0 ]) do |(category_id, values), totals|
        next if category_id.present? && category_index.key?(category_id)

        totals[0] += values.first
        totals[1] += values.last
      end
    end

    def selected_impact_modes
      return DEFAULT_IMPACT_MODES unless params[:impact_mode].present?

      [ params[:impact_mode] ]
    end

    def selected_month
      @selected_month ||= if params[:month].present?
        Date.parse("#{params[:month]}-01").beginning_of_month
      else
        today.beginning_of_month
      end
    end

    def current_period
      @current_period ||= begin
        month_range = selected_month.all_month
        current_period_partial? ? month_range.begin..[ today, month_range.end ].min : month_range
      end
    end

    def comparison_period
      @comparison_period ||= begin
        previous_month_range = selected_month.prev_month.all_month
        if current_period_partial?
          comparison_end = previous_month_range.begin + (current_period.end.day - 1).days
          previous_month_range.begin..[ comparison_end, previous_month_range.end ].min
        else
          previous_month_range
        end
      end
    end

    def current_period_partial?
      selected_month == today.beginning_of_month && today < selected_month.end_of_month
    end

    def period_payload(range, partial:)
      { from: range.begin.iso8601, to: range.end.iso8601, partial: partial }
    end

    def sort_nodes(nodes)
      nodes.sort_by { |node| [ -node.current_amount_cents, -node.previous_amount_cents, node.category.name.downcase, node.category.id ] }
    end

    def sort_entries(entries)
      entries.sort_by { |entry| [ -entry[:amount_cents], -entry[:previous_amount_cents], entry[:name].downcase, entry[:key] ] }
    end
  end
end
