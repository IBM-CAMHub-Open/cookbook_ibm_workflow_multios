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
# Provider:: workflow_createde

actions :prepare, :create, :start
default_action :create

# <> The installation root directory for the Business Automation Workflow.
attribute :install_dir, :kind_of => String, :default => nil

# <> The type of product configuration: Express, Standard, Advanced, or AdvancedOnly.
attribute :product_type, :kind_of => String, :default => nil

# <> The type of deployment environment: PC or PS. Use 'PC' to create a Workflow Center deployment environment and 'PS' to create a Workflow Server deployment environment.
attribute :deployment_type, :kind_of => String, :default => nil

# <> The type of cluster: SingleCluster or ThreeClusters(support later).
attribute :cluster_type, :kind_of => String, :default => nil

# <> The user name of the DE administrator.
attribute :deadmin_alias_user, :kind_of => String, :default => nil

# <> The password of the DE administrator.
attribute :deadmin_alias_password, :kind_of => String, :default => nil

# <> The user name of the cell administrator.
attribute :celladmin_alias_user, :kind_of => String, :default => nil

# <> The password of the cell administrator.
attribute :celladmin_alias_password, :kind_of => String, :default => nil

# <> The fully qualified domain name of the deployment manager to federate this node to.
attribute :dmgr_hostname, :kind_of => String, :default => nil

# <> The fully qualified domain name of this node.
attribute :node_hostname, :kind_of => String, :default => nil

# <> The fully qualified domain name of DB2 database.
attribute :db2_hostname, :kind_of => String, :default => nil

# <> The port number of the DB2 database.
attribute :db2_port, :kind_of => String, :default => nil

# <> The username of the DB2 database which will be used to create database user authentication alias.
attribute :db_alias_user, :kind_of => String, :default => nil

# <> The password of the DB2 database which will be used to create database user authentication alias.
attribute :db_alias_password, :kind_of => String, :default => nil

# <> The database name of Business Automation Workflow ProcessServerDb.
attribute :db2_bpmdb_name, :kind_of => String, :default => nil

# <> The database name of Business Automation Workflow PerformanceDb.
attribute :db2_pdwdb_name, :kind_of => String, :default => nil

# <> The database name of Business Automation Workflow CommonDB.
attribute :db2_cmndb_name, :kind_of => String, :default => nil

# <> The database name of Business Automation Workflow IcnDb/DosDb/TosDb.
attribute :db2_cpedb_name, :kind_of => String, :default => nil

# <> The database data directory path.
attribute :db2_data_dir, :kind_of => String, :default => nil

# <> The database name of Business Automation Workflow ShardDB.
attribute :db2_shareddb_name, :kind_of => String, :default => nil

# <> The database name of Business Automation Workflow CellOnlyDB.
attribute :db2_cellonlydb_name, :kind_of => String, :default => nil

# <> The database schema of Business Automation Workflow.
attribute :db2_schema, :kind_of => String, :default => nil

# <> The purpose of this Process Server environment: Development, Test, Staging, or Production, necessary for Process Server deployment environment.
attribute :ps_environment_purpose, :kind_of => String, :default => nil

# <> Options: true or false. Set to false if the Process Server is online and can be connected to the Process Center.
attribute :ps_offline, :kind_of => String, :default => nil

# <> Options: http or https. The transport protocol for communicating with the Process Center environment.
attribute :ps_pc_transport_protocol, :kind_of => String, :default => nil

# <> The host name of the Process Center environment.
attribute :ps_pc_hostname, :kind_of => String, :default => nil

# <> The port number of the Process Center environment.
attribute :ps_pc_port, :kind_of => String, :default => nil

# <> The context root prefix of the Process Center environment. If set, the context root prefix must start with a forward slash character (/).
attribute :ps_pc_contextroot_prefix, :kind_of => String, :default => nil

# <> The user name of the Process Center authentication alias (which is used by online Process Server environments to connect to Process Center).
attribute :ps_pc_alias_user, :kind_of => String, :default => nil

# <> The password of the Process Center authentication alias (which is used by online Process Server environments to connect to Process Center).
attribute :ps_pc_alias_password, :kind_of => String, :default => nil

# <> The DE creation properties file name.
attribute :createde_property_file, :kind_of => String, :default => nil

attr_accessor :database_created
attr_accessor :de_created
attr_accessor :de_started