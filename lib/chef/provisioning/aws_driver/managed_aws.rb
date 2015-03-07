require 'ipaddr'

class Chef
  module Provisioning
    module AWSDriver
      class ManagedAWS
        #
        # Create a new ManagedAWS getter.
        #
        # @param managed_entries [Chef::Provisioning::ManagedEntryStore] The storage
        #        where AWS IDs are associated with Chef names.
        # @param driver [Chef::Provisioning::Driver] The driver from which to get the
        #        object.
        def initialize(managed_entries, driver)
          @managed_entries = managed_entries
          @driver = driver
        end

        attr_reader :managed_entries
        attr_reader :driver

        #
        # Take a hash of AWS options and look up their IDs, one by one.
        #
        # @param options [Hash] Options to pass to an AWS method, with possible Chef names and resources.
        #
        # @return [Hash] Options to pass to an AWS method, with real AWS IDs.
        #
        def lookup_options(options)
          result = {}
          options.each do |name, value|
            if name.to_s.end_with?('_ids')
              type = name[0..-5].to_sym
              result[name] = Array[value].flatten.map { |v| lookup_aws_id!(type, v) || v }
            elsif name.to_s.end_with?('s')
              type = name[0..-2].to_sym
              result[name] = Array[value].flatten.map { |v| lookup_aws_id!(type, v) || v }
            elsif name.to_s.end_with?('_id')
              type = name[0..-4].to_sym
              result[name] = lookup_aws_id!(type, value) || value
            else
              result[name] = lookup_aws_id!(name.to_sym, value) || value
            end
          end
          result
        end

        #
        # Look up the AWS object ID.
        #
        # @param type The type of AWS object to get.
        # @param id The ID of the object.
        # @param required `true` if an error should be raised when the object does not
        #        exist.  The deepest error possible (such as the 404 response) will be
        #        raised.  If the input value is `nil`, `nil` will be returned rather
        #        than an error raised.
        #
        # @return The AWS object id.  If the ID cannot be found, `nil` is returned.
        #         The method may return ids even if the actual AWS object does not
        #         exist (it won't look in AWS in all cases).
        #
        def lookup_aws_id(type, id, required: false)
          return nil if id.nil?

          id = id.name if id.is_a?(Chef::Resource)

          case type
          when :eip_address
            begin
              IPAddr.new(id)
            rescue IPAddr::InvalidAddressError
              id = get_managed_id(:aws_eip_address, id, required: required)
            end
          when :image
            unless id =~ /^ami-[A-Fa-f0-9]{8}$/
              image = driver.ec2.images.filter('name', id).first
              if image && image.exists?
                id = image.id
              else
                raise "No image named #{id} found"
              end
            end
          when :instance
            unless id =~ /^i-[A-Fa-f0-9]{8}$/
              id = get_managed_id(:machine, id, key: 'instance_id', required: required)
            end
          when :security_group
            unless id =~ /^sg-[A-Fa-f0-9]{8}$/
              id = get_managed_id(:aws_security_group, id, required: required)
            end
          when :subnet
            unless id =~ /^subnet-[A-Fa-f0-9]{8}$/
              id = get_managed_id(:aws_subnet, id, required: required)
            end
          when :volume
            unless id =~ /^vol-[A-Fa-f0-9]{8}$/
              id = get_managed_id(:aws_volume, id, required: required)
            end
          when :vpc
            unless id =~ /^vpc-[A-Fa-f0-9]{8}$/
              id = get_managed_id(:aws_vpc, id, required: required)
            end
          end
          id
        end

        #
        # Look up the AWS object ID.  Fail if it does not exist.
        #
        # @param type The type of AWS object to get.
        # @param id The ID of the object.
        #
        # @return The AWS object id.  If the ID cannot be found, `nil` is returned.
        #         The method may return ids even if the actual AWS object does not
        #         exist (it won't look in AWS in all cases).
        #
        def lookup_aws_id!(type, id)
          lookup_aws_id(type, id, required: true)
        end

        #
        # Get an AWS object.
        #
        # @param type The type of AWS object to get
        # @param id The ID of the object.
        # @param required `true` if an error should be raised when the object does not
        #        exist.  The deepest error possible (such as the 404 response) will be
        #        raised.  If the input value is `nil`, `nil` will be returned rather
        #        than an error raised.
        #
        # @return The actual AWS object.  If the AWS object doesn't exist, the method
        #         may either return `nil` or an AWS object where `.exists?` is `false`.
        #
        def get_aws_object(type, id, required: false)
          id = lookup_aws_id(type, id, required: required)
          if id
            aws_object = case type
            when :auto_scaling_group
              driver.auto_scaling.groups[id]
            when :eip_address
              driver.ec2.elastic_ips[id]
            when :image
              driver.ec2.images[id]
            when :instance
              driver.ec2.instances[id]
            when :key_pair
              driver.ec2.key_pairs[id]
            when :launch_configuration
              driver.ec2.launch_configurations[id]
            when :load_balancer
              driver.elb.load_balancers[id]
            when :s3_bucket
              driver.s3.buckets[id]
            when :security_group
              driver.ec2.security_groups[id]
            when :sns_topic
              # TODO is this actually necessary?
              begin
                driver.sns.topics.named(name)
              rescue
                raise if required
                nil
              end
            when :sqs_queue
              begin
                driver.sqs.queues.named(name)
              rescue
                raise if required
                nil
              end
            when :subnet
              driver.ec2.subnets[id]
            when :vpc
              driver.ec2.vpcs[id]
            when :volume
              driver.ec2.volumes[id]
            else
              raise "Unknown AWS object type #{type.inspect}"
            end

            if !aws_object && required
              raise "#{type} #{id.inspect} not found"
            end
          end

          if !aws_object || (aws_object.respond_to?(:exists?) && !aws_object.exists?)
            raise "#{type} #{id.inspect} does not exist" if required
            aws_object = nil
          end

          aws_object
        end

        #
        # Get an AWS object.  Fail if it does not exist.
        #
        # @param type The type of AWS object to get
        # @param id The ID of the object.
        # @param required `true` if an error should be raised when the object does not
        #        exist.  The deepest error possible (such as the 404 response) will be
        #        raised.  If the input value is `nil`, `nil` will be returned rather
        #        than an error raised.
        #
        # @return The actual AWS object.  If the AWS object doesn't exist, the method
        #         may either return `nil` or an AWS object where `.exists?` is `false`.
        #
        def get_aws_object!(type, id)
          get_aws_object(type, id, required: true)
        end

        protected

        def get_managed_id(type, id, key: 'id', required: false)
          return nil if id.nil?

          if required
            entry = managed_entries.get!(type, id)
          else
            entry = managed_entries.get(type, id)
          end

          if entry
            entry.reference[key]
          else
            nil
          end
        end
      end
    end
  end
end
