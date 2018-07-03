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
# Cookbook Name::workflow
# Recipe::createde
#
# <> Configures IBM Business Automation Workflow SingleCluster topology
#

# TODO: try to meet the rule - all CHEF Cookbook's and Recipe's must be inherently idempotent.
product_type = node['workflow']['config']['product_type']
deployment_type = node['workflow']['config']['deployment_type']
cluster_type = node['workflow']['config']['cluster_type']

if cluster_type != 'SingleCluster' && cluster_type != 'ThreeClusters'
  Chef::Log.fatal "Please make sure you have the right value('SingleCluster' or 'ThreeClusters') for attribute ['workflow']['config']['cluster_type'], the input one is #{cluster_type}"
  raise "Please make sure you have the right value('SingleCluster' or 'ThreeClusters') for attribute ['workflow']['config']['cluster_type'], the input one is #{cluster_type}"
end

if !(['Advanced', 'Standard', 'AdvancedOnly'].include? product_type)
  Chef::Log.fatal "Please make sure you have the right value for attribute ['workflow']['config']['product_type'], the input one is #{product_type}"
  raise "Please make sure you have the right value for attribute ['workflow']['config']['product_type'], the input one is #{product_type}"
end

if deployment_type != 'PC' && deployment_type != 'PS'
  Chef::Log.fatal "Please make sure you have the right value('PC' or 'PS') for attribute ['workflow']['config']['deployment_type'], the input one is #{deployment_type}"
  raise "Please make sure you have the right value('PC' or 'PS') for attribute ['workflow']['config']['deployment_type'], the input one is #{deployment_type}"
end

# TODO: check the required attributes are passed in

# Construct DE creation properties file name according to product_type, deployment_type and cluster_type.
createde_property_file = ''
case product_type
  when 'Advanced', 'Standard'
    createde_property_file = "#{product_type}-#{deployment_type}-#{cluster_type}-DB2.properties"
  when 'AdvancedOnly'
    createde_property_file = "#{product_type}-#{cluster_type}-DB2.properties"
  else
    # no way to go into this path, should be checked in previous step
end
Chef::Log.info("createde_property_file:#{createde_property_file}")

# decrypt the encrypted data, all kinds of password are encrypted.
chef_vault = node['workflow']['vault']['name']

celladmin_alias_password = node['workflow']['config']['celladmin_alias_password']
deadmin_alias_password = node['workflow']['config']['deadmin_alias_password']
db_alias_password = node['workflow']['config']['db_alias_password']
ps_pc_alias_password = node['workflow']['config']['ps_pc_alias_password']
unless chef_vault.empty?
  #Chef::Log.info("Before decryption: celladmin_alias_password: #{celladmin_alias_password}, deadmin_alias_password: #{deadmin_alias_password}, db_alias_password: #{db_alias_password}, ps_pc_alias_password: #{ps_pc_alias_password}")
  encrypted_id = node['workflow']['vault']['encrypted_id']
  require 'chef-vault'
  celladmin_alias_password = chef_vault_item(chef_vault, encrypted_id)['workflow']['config']['celladmin_alias_password']
  deadmin_alias_password = chef_vault_item(chef_vault, encrypted_id)['workflow']['config']['deadmin_alias_password']
  db_alias_password = chef_vault_item(chef_vault, encrypted_id)['workflow']['config']['db_alias_password']
  ps_pc_alias_password = chef_vault_item(chef_vault, encrypted_id)['workflow']['config']['ps_pc_alias_password']
end

workflow_createde 'ibm_workflow_createde' do
  install_dir  node['workflow']['install_dir']
  product_type  node['workflow']['config']['product_type']
  deployment_type  node['workflow']['config']['deployment_type']
  cluster_type  node['workflow']['config']['cluster_type']
  deadmin_alias_user  node['workflow']['config']['deadmin_alias_user']
  deadmin_alias_password  deadmin_alias_password
  celladmin_alias_user  node['workflow']['config']['celladmin_alias_user']
  celladmin_alias_password  celladmin_alias_password
  dmgr_hostname  node['workflow']['config']['dmgr_hostname']
  node_hostname  node['workflow']['config']['node_hostname']
  db2_hostname  node['workflow']['config']['db2_hostname']
  db2_port  node['workflow']['config']['db2_port']
  db_alias_user  node['workflow']['config']['db_alias_user']
  db_alias_password  db_alias_password
  db2_bpmdb_name  node['workflow']['config']['db2_bpmdb_name']
  db2_pdwdb_name  node['workflow']['config']['db2_pdwdb_name']
  db2_cmndb_name  node['workflow']['config']['db2_cmndb_name']
  db2_cpedb_name  node['workflow']['config']['db2_cpedb_name']
  db2_data_dir  node['workflow']['config']['db2_data_dir']
  db2_shareddb_name  node['workflow']['config']['db2_shareddb_name']
  db2_cellonlydb_name  node['workflow']['config']['db2_cellonlydb_name']
  db2_schema  node['workflow']['config']['db2_schema']
  ps_environment_purpose  node['workflow']['config']['ps_environment_purpose']
  ps_offline  node['workflow']['config']['ps_offline']
  ps_pc_transport_protocol  node['workflow']['config']['ps_pc_transport_protocol']
  ps_pc_hostname  node['workflow']['config']['ps_pc_hostname']
  ps_pc_port  node['workflow']['config']['ps_pc_port']
  ps_pc_contextroot_prefix  node['workflow']['config']['ps_pc_contextroot_prefix']
  ps_pc_alias_user  node['workflow']['config']['ps_pc_alias_user']
  ps_pc_alias_password  ps_pc_alias_password
  createde_property_file createde_property_file
  action [:prepare, :create, :start]
end
