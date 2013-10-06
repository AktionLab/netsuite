module NetSuite
  module Records
    class Item
      include Support::Fields
      include Support::RecordRefs
      include Support::Records
      include Support::Actions
      include Namespaces::ListAcct

      actions :search
    end
  end
end
