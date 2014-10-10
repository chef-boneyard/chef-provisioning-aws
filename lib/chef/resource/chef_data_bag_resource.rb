require 'chef/resource/lwrp_base'
require 'cheffish'

# A resource that is backed by a data bag
class Chef::Resource::ChefDataBagResource < Chef::Resource::LWRPBase

  actions :create, :delete, :nothing, :update

  # The key to store this thing under (/data/bag/<<name>>)
  attr_reader :name

  class << self
    attr_reader :databag_name
    attr_reader :stored_attributes
  end

  def initialize(name, run_context=nil)
    super
    Chef::Log.debug("Re-hydrating #{name} from #{self.class.databag_name}...")
    self.hydrate
  end

  def self.stored_attributes
    @stored_attributes || []
  end

  def self.databag_name= name
    Chef::Log.debug("Setting databag name to #{name}")
    @databag_name = name
  end

  def self.attr_accessor(*vars)
    @attributes ||= []
    @attributes.concat vars

    @writable ||= []
    @writable.concat vars
    super
  end

  def self.attr_reader(*vars)
    @attributes ||= []
    @attributes.concat vars

    @readonly ||= []
    @readonly.concat vars
    super
  end

  def self.stored_attribute(*vars)
    attr_name = vars[0]
    @stored_attributes ||= []
    @stored_attributes << attr_name
    self.attribute attr_name
  end

  #
  # Load persisted data from the server's databag. If the databag does not exist on the
  # server, returns nil.
  #
  def hydrate(chef_server = Cheffish.default_chef_server)
    chef_api = Cheffish.chef_server_api(chef_server)
    begin
      data = chef_api.get("/data/#{self.class.databag_name}/#{name}")
      load_from_hash(data)
      Chef::Log.debug("HASH: #{data}")
    rescue Net::HTTPServerException => e
      if e.response.code == '404'
        nil
      else
        raise
      end
    end
  end

  def load_from_hash hash
    hash.each do |k,v|
      begin
        self.instance_variable_set("@#{k}", v)
      rescue NameError => ne
        # do nothing ...
        # TODO: warn / complain?
      end
    end
    self
  end

  def to_hash(*a)
    ignored = []

    hash = {}
    (self.class.stored_attributes - ignored).each do |attr_name|
      varname = "@#{attr_name.to_s.gsub('@', '')}"
      key = varname.gsub('@', '')
      hash[key] = self.instance_variable_get varname
    end

    hash
  end


  #
  # Save this entity to the server.  If you have significant information that
  # could be lost, you should do this as quickly as possible.
  #
  def save

    create_databag_if_needed self.class.databag_name

    # Clone for inline_resource
    _databag_name = self.class.databag_name
    _hash = self.to_hash
    _name = self.name

    Cheffish.inline_resource(self, :create) do
      chef_data_bag_item _name do
        data_bag _databag_name
        raw_data _hash
        action :create
      end
    end
  end

  # Delete this entity from the server
  def delete
    # Clone for inline_resource
    _name = self.name
    _databag_name = self.class.databag_name

    Cheffish.inline_resource(self, :delete) do
      chef_data_bag_item _name do
        data_bag _databag_name
        action :destroy
      end
    end
  end

  def new_resource
    self
  end

  private
  def create_databag_if_needed databag_name
    _databag_name = databag_name
    Cheffish.inline_resource(self, :create) do
      chef_data_bag _databag_name do
        action :create
      end
    end
  end
end

