module NetSuite
  module Records
    class PurchaseOrderExpenseList
      include Support::Fields
      include Namespaces::TranPurch

      fields :expense

      def initialize(attributes = {})
        initialize_from_attributes_hash(attributes)
      end

      def expense=(expenses)
        case expenses
        when Hash
          self.expenses << PurchaseOrderExpense.new(expenses)
        when Array
          expenses.each { |expense| self.expenses << PurchaseOrderExpense.new(expense) }
        end
      end

      def expenses
        @expenses ||= []
      end

      def to_record
        { "#{record_namespace}:expense" => expenses.map(&:to_record) }
      end

    end
  end
end
