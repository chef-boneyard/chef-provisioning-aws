class Chef
module Provisioning
module AWSDriver
module Exceptions

  class MultipleSecurityGroupError < RuntimeError
    def initialize(name, groups)
      super "Found security groups with ids [#{groups.map {|sg| sg.id}}] that share name #{name}. " \
        "Names are unique within VPCs - specify VPC to find by name."
    end
  end

end
end
end
end
