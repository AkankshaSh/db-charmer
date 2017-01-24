#
# This class is used to automatically generate small abstract ActiveRecord classes
# that would then be used as a source of database connections for DbCharmer magic.
# This way we do not need to re-implement all the connection establishing code
# that ActiveRecord already has and we make our code less dependant on Rails versions.
#
module DbCharmer
  module ConnectionFactory
    def self.connection_classes
      Thread.current[:db_charmer_generated_connection_classes] ||= {}
    end

    def self.connection_classes=(val)
      Thread.current[:db_charmer_generated_connection_classes] = val
    end

    def self.reset!
      self.connection_classes = {}
    end

    # Establishes connection or return an existing one from cache
    def self.connect(connection_name, should_exist = true)
      connection_name = connection_name.to_s
      connection_classes[connection_name] ||= establish_connection(connection_name, should_exist)
    end

    # Establishes connection or return an existing one from cache (not using AR database configs)
    def self.connect_to_db(connection_name, config)
      connection_name = connection_name.to_s
      connection_classes[connection_name] ||= establish_connection_to_db(connection_name, config)
    end

    # Establish connection with a specified name
    def self.establish_connection(connection_name, should_exist = true)
      abstract_class = generate_abstract_class(connection_name, should_exist)
      DbCharmer::ConnectionProxy.new(abstract_class, connection_name)
    end

    # Establish connection with a specified name (not using AR database configs)
    def self.establish_connection_to_db(connection_name, config)
      abstract_class = generate_abstract_class_for_db(connection_name, config)
      DbCharmer::ConnectionProxy.new(abstract_class, connection_name)
    end

    # Generate an abstract AR class with specified connection established
    def self.generate_abstract_class(connection_name, should_exist = true)
      # Generate class
      klass = generate_empty_abstract_ar_class(abstract_connection_class_name(connection_name))

      # Establish connection
      klass.establish_real_connection_if_exists(connection_name.to_sym, !!should_exist)

      # Return the class
      return klass
    end

    # Generate an abstract AR class with specified connection established (not using AR database configs)
    def self.generate_abstract_class_for_db(connection_name, config)
      # Generate class
      klass = generate_empty_abstract_ar_class(abstract_connection_class_name(connection_name))

      # Establish connection
      klass.establish_connection(config)

      # Return the class
      return klass
    end

    def self.generate_empty_abstract_ar_class(klass)
      # Define class
      module_eval "class #{klass} < ::ActiveRecord::Base; self.abstract_class = true; end"

      # Return class
      klass.constantize
    end

    # Generates unique names for our abstract AR classes
    def self.abstract_connection_class_name(connection_name)
      conn_name_klass = connection_name.to_s.gsub(/\W+/, '_').camelize
      thread = Thread.current.object_id.abs # need to make sure it is non-negative
      "::AutoGeneratedAbstractConnectionClass#{conn_name_klass}ForThread#{thread}"
    end
  end
end
