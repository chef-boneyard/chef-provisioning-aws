# A simple load balancer for HTTP on port 80
load_balancer "test-elb" do
    machines [ "machine1", "machine2" ]
    load_balancer_options :listeners => [{
        :port => 80,
        :protocol => :http,
        :instance_port => 80,
        :instance_protocol => :http,
    }]
end


# A more complex load balancer.
# This creates 10 t2.micro instances, and then adds them to a load balancer.
# We can also specify the subnets and the security groups, both of which can be
# strings or arrays. 
#   :scheme defaults to "internet-facing", we can override it to be "internal".
num_instances = 10

1.upto(num_instances) do |inst|
    machine "my-machine-#{inst}" do
        add_machine_options bootstrap_options: {
            security_group_ids: 'test-sg',
            subnet_id: 'subnet-1234567',
            instance_type: 't2.micro'
        }
    end
end

load_balancer "test-elb" do
    machines (1..num_instances).map { |inst| "my-machine-#{inst}" }
    load_balancer_options :listeners => [{
        :port => 80,
        :protocol => :http,
        :instance_port => 80,
        :instance_protocol => :http,
    }],
    :scheme => "internal",
    :subnets => "subnet-1234567",
    :security_groups => "test-sg"
end
