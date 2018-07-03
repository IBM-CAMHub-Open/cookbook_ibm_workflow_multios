# =================================================================
# Copyright 2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =================================================================

#
# Cookbook Name:: workflow 
# Provider:: workflow_install
#
#actions :install, :install_im, :upgrade_im
actions :prepare, :install_im, :install, :applyifix, :cleanup
default_action :install

# <> The repository to search. 
attribute :sw_repo, :kind_of => String, :default => node['ibm']['im_repo']

# <> User used to access IM repo if this repo is secured and authentication is required This is not required if IM repo is not secured.
attribute :im_repo_user, :kind_of => String, :default => nil

# <> If the software repo is public this should be set to "false"
attribute :secure_repo, :kind_of => String, :default => 'true'

# <> If the IM repo is secured but it uses a self signed SSL certificate this should be set to "true"
attribute :im_repo_nonsecureMode, :kind_of => String, :default => 'false'

# <> If the Software repo is secured but it uses a self signed SSL certificate this should be set to "true"
attribute :repo_nonsecureMode, :kind_of => String, :default => 'false'

# <> The response file for the IBM Installation Manager.
attribute :response_file, :kind_of => String, :default => nil

# <> The DB2 response file for the IBM Installation Manager.
attribute :db2_response_file, :kind_of => String, :default => nil

# <> Installation directory for the product that is installed using this LWRP
attribute :install_dir, :kind_of => String, :default => nil

# possible values:
# offering_id                                            profile_id
# com.ibm.bpm.ADV.v85		->	   IBM Business Automation Workflow 18001
# <> Offering ID. You can find the value in your IMRepo. Each Product has a different ID
attribute :offering_id, :kind_of => String, :default => nil

# <> Offering version. You can find the value in your IMRepo. 
attribute :offering_version, :kind_of => String, :default => nil

# possible values:
# was_offering_id                                        profile_id
# com.ibm.websphere.ND.v85      ->         IBM WebSphere Application Server V8.5
attribute :was_offering_id, :kind_of => String, :default => nil

# possible values:
# db2_offering_id                                        profile_id
# com.ibm.ws.DB2EXP.linuxia64   ->         IBM DB2 Advanced Workgroup Server Edition
attribute :db2_offering_id, :kind_of => String, :default => nil

# DB2 offering version. You can find the value in your IMRepo. 
attribute :db2_offering_version, :kind_of => String, :default => nil

# com.ibm.websphere.IHS.v85     ->         IBM HTTP Server for WebSphere Application Server V8.5

# <> Profile ID. This is a description of the product
attribute :profile_id, :kind_of => String, :default => nil

# <> Feature list for the product. This is a list of components that should be installed for a specific product
attribute :feature_list, :kind_of => String, :default => nil

# <> Directory where installation artifacts are stored.
attribute :im_shared_dir, :kind_of => String, :default => nil

# <> User used to install IM and that should be used to install a product
attribute :user, :kind_of => String, required: true, :default => nil

# <> Group used to install IM and that should be used to install a product
attribute :group, :kind_of => String, required: true, :default => nil

# <> Installation mode used to install IM and that should be used to install a product
attribute :im_install_mode, :kind_of => String, :default => 'admin'

# <> Directory where im was installed
attribute :im_install_dir, :kind_of => String, :default => nil

# <> An absolute path to a directory that will be used to hold any persistent files created as part of the automation
attribute :ibm_log_dir, :kind_of => String, :default => nil

# <> Installation Manager Version Number to be installed. Supported versions: 1.8.9 for Workflow 18.0.0.1
attribute :im_version, :kind_of => String, :default => nil

# <> Installation Manager Data Directory
attribute :im_data_dir, :kind_of => String, :default => nil


# <> Install DB2 Advanced Workgroup Server Edition
# <> Install Embeded DB2 or not
attribute :db2_install, :kind_of => String, :default => 'false'
# <> Port, DB2 connection port
attribute :db2_port, :kind_of => String, :default => '50000'
# <> DB2 instance user name, db2inst1 as default
attribute :db2_username, :kind_of => String, :default => 'db2inst1'
# <> DB2 instance user password
attribute :db2_password, :kind_of => String, :default => nil
# <> Create new DB2 das user or not
attribute :db2_das_newuser, :kind_of => String, :default => 'true'
# <> Create new DB2 fenced user or not
attribute :db2_fenced_newuser, :kind_of => String, :default => 'true'
# <> DB2 das user name, dasusr1 as default
attribute :db2_das_username, :kind_of => String, :default => 'dasusr1'
# <> DB2 das user password
attribute :db2_das_password, :kind_of => String, :default => nil
# <> DB2 fenced user name, db2fenc1 as default
attribute :db2_fenced_username, :kind_of => String, :default => 'db2fenc1'
# <> DB2 fenced user password
attribute :db2_fenced_password, :kind_of => String, :default => nil


# <> Apply ifixes
# <> The repository to search ifixes.
attribute :ifix_repo, :kind_of => String, :default => node['ibm']['ifix_repo']
# <> Ifix names, format like "ifix1.zip, ifix2,zip, ifix3.zip"
attribute :ifix_names, :kind_of => String, :default => nil


attr_accessor :im_installed
attr_accessor :fp_installed
attr_accessor :installed
