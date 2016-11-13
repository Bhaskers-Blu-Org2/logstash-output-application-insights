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
  class Validate_storage

    public

    def initialize
      configuration = Config.current
      @storage_account_name_key = configuration[:storage_account_name_key]
    end

    def validate
      result = []
      @storage_account_name_key.each do |storage_account_name, storage_account_keys|
        test_storage = Test_storage.new( storage_account_name )
        result << { :storage_account_name => storage_account_name, :test => "create container", :success => test_storage.test_container, :error => test_storage.last_io_exception }
        result << { :storage_account_name => storage_account_name, :test => "create table", :success => test_storage.test_table, :error => test_storage.last_io_exception }
      end
      result
    end
  end
end
