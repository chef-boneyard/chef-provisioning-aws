require 'chef/provisioning/aws_driver'

with_driver 'aws::eu-west-1'

vpc = aws_vpc 'test-vpc' do
  cidr_block '10.0.0.0/24'
  internet_gateway true
end

# Empty

aws_security_group 'test-sg' do
  vpc 'test-vpc'
  action :delete
end

aws_security_group 'test-sg' do
  vpc 'test-vpc'
end
aws_security_group 'test-sg' do
  vpc 'test-vpc'
end

# Things we can reference
aws_security_group 'other-sg' do
  vpc 'test-vpc'
end

aws_subnet 'test-subnet' do
  vpc 'test-vpc'
end

recipe = self
ruby_block 'lb' do
  block do
    recipe.load_balancer 'other-lb' do
      load_balancer_options subnets: vpc.aws_object.subnets.map { |s| s }
    end
  end
end

# Add/update
aws_security_group 'test-sg' do
  vpc 'test-vpc'
  action :delete
end
aws_security_group 'test-sg' do
  vpc 'test-vpc'
  inbound_rules '0.0.0.0/0'                   => 22,
                'other-sg'                    => 1024..2048,
                { load_balancer: 'other-lb' } => 1024..2048
  outbound_rules 443        => '0.0.0.0/0',
                 2048..4096 => 'other-sg',
                 2048..4096 => { load_balancer: 'other-lb' }
end

# Add one inbound rule, change one inbound rule, add to one inbound rule
aws_security_group 'test-sg' do
  vpc 'test-vpc'
  inbound_rules '0.0.0.0/0' => 80,
                'other-sg'  => [ 80, 1024..2048 ],
                '127.0.0.1' => 1024..2048,
                { load_balancer: 'other-lb' } => 1024..2048
end

# Add one outbound rule, change one outbound rule, add to one outbound rule
aws_security_group 'test-sg' do
  vpc 'test-vpc'
  outbound_rules 80                 => '0.0.0.0/0',
                 [ 80, 2048..4096 ] => 'other-sg',
                 2048..4096         => '127.0.0.1',
                 1024..2048         => { load_balancer: 'other-lb' }
end


# Idempotence
aws_security_group 'test-sg' do
  vpc 'test-vpc'
  inbound_rules '0.0.0.0/0'                   => 80,
                'other-sg'                    => [ 80, 1024..2048 ],
                '127.0.0.1'                   => 1024..2048,
                { load_balancer: 'other-lb' } => 1024..2048
  outbound_rules 80                 => '0.0.0.0/0',
                 [ 80, 2048..4096 ] => 'other-sg',
                 2048..4096         => '127.0.0.1',
                 1024..2048         => { load_balancer: 'other-lb' }
end

# Idempotence (alternate way of writing it)
aws_security_group 'test-sg' do
  vpc 'test-vpc'
  inbound_rules [{ port: 80, sources: [ '0.0.0.0/0' ] },
                { port: [ 80, 1024..2048 ], sources: [ 'other-sg' ] },
                { port: 1024..2048, sources: [ '127.0.0.1' ] },
                { port: 1024..2048, sources: [ { load_balancer: 'other-lb' } ] }]
  outbound_rules [{ port: 80, destinations: [ '0.0.0.0/0', 'other-sg' ] },
                 { port: [ 80, 2048..4096 ], destinations: [ 'other-sg' ] },
                 { port: 2048..4096, destinations: [ 'other-sg', '127.0.0.1' ] },
                 { port: 1024..2048, destinations: [ { load_balancer: 'other-lb' } ] }]
end

load_balancer 'other-lb' do
  action :destroy
end

aws_subnet 'test-subnet' do
  action :delete
end

aws_security_group 'test-sg' do
  action :delete
end

aws_security_group 'other-sg' do
  action :delete
end

aws_vpc 'test-vpc' do
  action :delete
end
