module Helene
  module S3
    class Grantee
      attr_reader :thing
      attr_reader :id
      attr_reader :name
      attr_accessor :perms
        
      def self.owner_and_grantees(thing)
        if thing.is_a?(Bucket)
          bucket, key = thing, ''
        else
          bucket, key = thing.bucket, thing
        end
        hash = bucket.interface.get_acl_parse(bucket.to_s, key.to_s)
        owner = Owner.new(hash[:owner][:id], hash[:owner][:display_name])
        
        grantees = []
        hash[:grantees].each do |id, params|
          grantees << new(thing, id, params[:permissions], nil, params[:display_name])
        end
        [owner, grantees]
      end

      def self.grantees(thing)
        owner_and_grantees(thing)[1]
      end

      def self.put_acl(thing, owner, grantees) #:nodoc:
        if thing.is_a?(Bucket)
          bucket, key = thing, ''
        else
          bucket, key = thing.bucket, thing
        end
        body = "<AccessControlPolicy>" +
               "<Owner>" +
               "<ID>#{owner.id}</ID>" +
               "<DisplayName>#{owner.name}</DisplayName>" +
               "</Owner>" +
               "<AccessControlList>" +
               grantees.map{|grantee| grantee.to_xml}.join +
               "</AccessControlList>" +
               "</AccessControlPolicy>"
        bucket.interface.put_acl(bucket.to_s, key.to_s, body)
      end

      def initialize(thing, id, perms=[], action=:refresh, name=nil)
        @thing = thing
        @id    = id
        @name  = name
        @perms = perms.to_a
        case action
          when :apply:             apply
          when :refresh:           refresh
          when :apply_and_refresh: apply; refresh
        end
      end
      
      def exists?
        self.class.grantees(@thing).each do |grantee|
          return true if @id == grantee.id
        end
        false
      end
      
      def type
        @id[/^http:/] ? "Group" : "CanonicalUser"
      end
 
      def to_s
        @name || @id
      end
      
      def grant(*permissions)
        permissions.flatten!
        old_perms = @perms.dup
        @perms   += permissions
        @perms.uniq!
        return true if @perms == old_perms
        apply
      end
      
      def revoke(*permissions)
        permissions.flatten!
        old_perms = @perms.dup
        @perms   -= permissions
        @perms.uniq!
        return true if @perms == old_perms
        apply
      end
     
      def drop
        @perms = []
        apply
      end
         
      def refresh
        @perms = []
        self.class.grantees(@thing).each do |grantee|
          if @id == grantee.id
            @name  = grantee.name
            @perms = grantee.perms
            return true
          end
        end
        false
      end

      def apply
        @perms.uniq!
        owner, grantees = self.class.owner_and_grantees(@thing)
        # walk through all the grantees and replace the data for the current one and ...
        grantees.map! { |grantee| grantee.id == @id ? self : grantee }
        # ... if this grantee is not known - add this bad boy to a list
        grantees << self unless grantees.include?(self)
        # set permissions
        self.class.put_acl(@thing, owner, grantees)
      end

      def to_xml
        id_str = @id[/^http/] ? "<URI>#{@id}</URI>" : "<ID>#{@id}</ID>"
        grants = ''
        @perms.each do |perm|
          grants << "<Grant>"    +
                    "<Grantee xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" " +
                      "xsi:type=\"#{type}\">#{id_str}</Grantee>" +
                    "<Permission>#{perm}</Permission>" +
                    "</Grant>"
        end
        grants
      end
    end
  end
end
