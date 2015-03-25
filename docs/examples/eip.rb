require 'chef/provisioning/aws_driver'

with_driver 'aws::us-west-2' do

    machine "SRV_OR_Web_1" do
        machine_options :bootstrap_options => {
          :key_name => 'Tst_Prov'
        }
    end

    #create a new eip and associate it to the machine
    #Note: in order to be able to associate an eip to a
    # machine in a vpc, set "associate_to_vpc true"
    # whenever you create an EIP
    aws_eip_address "Web_IP_1" do
        machine "SRV_OR_Web_1"
    end

    #Delete EIP - Will disassociate and release
    aws_eip_address "Web_IP_1" do
        action :destroy
    end
end
# You can create an EIP without associating it to a machine with the :create action
# You can also disassociate an EIP without releasing with the :disassociate action
# Existing EIPs can be hooked by specifying the public_ip attribute and then an action
