# encoding: utf-8

# ----------------------------------------------------------------------------------
# Logstash Output Application Insights
#
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
#
# Licensed under the Apache License, Version 2.0 (the License); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 
#
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
#
# See the Apache Version 2.0 License for specific language governing 
# permissions and limitations under the License.
# ----------------------------------------------------------------------------------

class LogStash::Outputs::Application_insights
  class Client

    public

    def initialize ( storage_account_name, force = nil )
      @storage_account_name = storage_account_name
      @storage_account = Clients.instance.active_storage_account( storage_account_name, force )

      @tuple = @storage_account[:clients_Q].pop
      ( @current_storage_account_key_index, @current_azure_storage_auth_sas, @current_azure_storage_client) = @tuple
      if @current_storage_account_key_index != @storage_account[:valid_index]
        @current_storage_account_key_index = @storage_account[:valid_index]
        set_current_storage_account_client
        @tuple = [ @current_storage_account_key_index, @current_azure_storage_auth_sas, @current_azure_storage_client ]
      end 
      @storage_account_key_index = @current_storage_account_key_index
    end

    def dispose ( io_failed_reason = nil )
      if @tuple 
        if  @current_storage_account_key_index == @storage_account_key_index
          @storage_account[:clients_Q] << @tuple
        else
          @storage_account[:valid_index] = @current_storage_account_key_index
          @storage_account[:clients_Q] << [ @current_storage_account_key_index, @current_azure_storage_auth_sas, @current_azure_storage_client ]
        end
        @tuple = nil

        Clients.instance.failed_storage_account( @storage_account_name, io_failed_reason ) if io_failed_reason && :blobClient == @last_client_type
      end
      nil
    end

    def blobClient
      raise UnexpectedBranchError, "client already disposed" unless @tuple
      @last_client_type = :blobClient
      # breaking change after azure-storage 0.10.1 
      # @current_azure_storage_client.blobClient
      @current_azure_storage_client.blob_client
    end

    def tableClient
      raise UnexpectedBranchError, "client already disposed" unless @tuple
      @last_client_type = :blobClient
      # breaking change after azure-storage 0.10.1 
      # @current_azure_storage_client.tableClient
      @current_azure_storage_client.table_client
    end

    def notifyClient
      raise UnexpectedBranchError, "client already disposed" unless @tuple
      @last_client_type = :notifyClient
      @current_azure_storage_client
    end

    def storage_auth_sas
      raise UnexpectedBranchError, "client already disposed" unless @tuple
      @current_azure_storage_auth_sas
    end


    def switch_storage_account_key!
      raise UnexpectedBranchError, "client already disposed" unless @tuple
      @current_storage_account_key_index = ( @current_storage_account_key_index + 1 ) % @storage_account[:keys].length
      if @current_storage_account_key_index == @storage_account_key_index
        rollback_storage_account_key
        false
      else
        set_current_storage_account_client
        true
      end
    end

    private

    def rollback_storage_account_key
      raise UnexpectedBranchError, "client already disposed" unless @tuple
      ( @current_storage_account_key_index, @current_azure_storage_auth_sas, @current_azure_storage_client) = @tuple
    end

    def set_current_storage_account_client
      configuration = Config.current
      storage_access_key = @storage_account[:keys][@current_storage_account_key_index]

      options = { 
        :storage_account_name => @storage_account_name, 
        :storage_access_key => storage_access_key,
        :storage_blob_host => "https://#{@storage_account_name}.#{:blob}.#{configuration[:azure_storage_host_suffix]}",
        :storage_table_host => "https://#{@storage_account_name}.#{:table}.#{configuration[:azure_storage_host_suffix]}"
      }
      options[:ca_file] = configuration[:ca_file] unless configuration[:ca_file].empty?

      @current_azure_storage_client = Azure::Storage::Client.new( options )
      # breaking change after azure-storage 0.10.1 
      # @current_azure_storage_auth_sas = Azure::Storage::Auth::SharedAccessSignature.new( @storage_account_name, storage_access_key )
      @current_azure_storage_auth_sas = Azure::Storage::Core::Auth::SharedAccessSignature.new( @storage_account_name, storage_access_key )
    end

  end
end
