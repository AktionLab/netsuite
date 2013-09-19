module NetSuite
  module Records
    class PurchaseOrderItem
      include Support::Fields
      include Support::RecordRefs
      include Support::Records
      include Namespaces::TranPurch

      #field :inventory_detail, InventoryDetail
      field :custom_field_list, CustomFieldList
      field :options, CustomFieldList

      record_refs :klass, :customer, :department, :item, :landed_cost_category, :location, :tax_code, :units

      #field :bill_variance_status, TransactionBillVarianceStatus

      fields :amount, :description, :expected_receipt_date, :gross_amt, :is_billable, :is_closed, :line, :match_bill_to_receipt, :quantity, :quantity_available, :quantity_billed, :quantity_on_hand, :quantity_received, :rate, :serial_numbers, :tax_1_amt, :tax_rate_1, :tax_rate_2, :vendor_name

      def initialize(attributes_or_record = {})
        case attributes_or_record
        when Hash
          initialize_from_attributes_hash(attributes_or_record)
        when self.class
          initialize_from_record(attributes_or_record)
        end
      end

      def initialize_from_record(record)
        self.attributes = record.send(:attributes)
      end

      def to_record
        rec = super
        if rec["#{record_namespace}:customFieldList"]
          rec["#{record_namespace}:customFieldList!"] = rec.delete("#{record_namespace}:customFieldList")
        end
        rec
      end

    end
  end
end
