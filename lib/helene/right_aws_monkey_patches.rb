

module RightAws
  class SdbInterface

    def delete_attributes(domain_name, item_name, attributes = nil)
      params = { 'DomainName' => domain_name,
                 'ItemName'   => item_name }.merge(pack_attributes(attributes, :method => :delete))
      link = generate_request("DeleteAttributes", params)
      request_info( link, QSdbSimpleParser.new )
    rescue Exception
      on_exception
    end

  end
end
