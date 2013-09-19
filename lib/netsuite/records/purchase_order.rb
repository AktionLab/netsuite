module NetSuite
  module Records
    class PurchaseOrder
      include Support::Fields
      include Support::RecordRefs
      include Support::Records
      include Support::Actions
      include Namespaces::TranPurch

      actions :get, :add, :initialize, :delete, :update, :search

      field :transaction_bill_address, BillAddress
      field :transaction_ship_address, ShipAddress
      field :custom_field_list, CustomFieldList

      field :expense_list, PurchaseOrderExpenseList
      field :item_list, PurchaseOrderItemList
      #field :order_status, PurchaseOrderOrderStatus

      record_refs :approval_status, :bill_address_list, :klass, :created_from, :currency, :custom_form, :department, :employee, :entity, :interco_transaction, :location, :next_approver, :ship_address_list, :ship_method, :ship_to, :subsidiary, :terms

      fields :bill_address, :created_date, :currency_name, :due_date, :email, :exchange_rate, :fax, :fob, :last_modified_date, :linked_tracking_numbers, :memo, :message, :other_ref_num, :ship_address, :ship_date, :source, :status, :sub_total, :supervisor_approval, :tax_2_total, :tax_total, :to_be_emailed, :to_be_faxed, :to_be_printed, :total, :tracking_numbers, :tran_date, :tran_id, :vat_reg_num

      attr_reader :internal_id
      attr_accessor :external_id
      attr_accessor :search_joins

      def initialize(attributes = {})
        @internal_id = attributes.delete(:internal_id) || attributes.delete(:@internal_id)
        @external_id = attributes.delete(:external_id) || attributes.delete(:@external_id)
        initialize_from_attributes_hash(attributes)
      end

    end
  end
end
