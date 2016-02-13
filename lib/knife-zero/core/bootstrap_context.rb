require 'chef/knife/core/bootstrap_context'
require "knife-zero/helper"

class Chef
  class Knife
    module Core
      class BootstrapContext
         class_eval do
           alias :orig_validation_key validation_key
           def validation_key
             if @chef_config[:knife_zero]
               OpenSSL::PKey::RSA.new(2048).to_s
             else
               orig_validation_key
             end
           end

           alias :orig_config_content config_content
           def config_content
             client_rb = orig_config_content
             white_lists = []
             %w{ automatic_attribute_whitelist default_attribute_whitelist normal_attribute_whitelist override_attribute_whitelist }.each do |white_list|
               if Chef::Config[:knife][white_list.to_sym] && Chef::Config[:knife][white_list.to_sym].is_a?(Array)
                 white_lists.push([
                   white_list,
                   Chef::Config[:knife][white_list.to_sym].to_s
                 ].join(" "))
               end
             end
             client_rb << white_lists.join("\n")

             ## For support policy_document_native_api
             if @config[:policy_name]
               @config[:policy_group] = "local"
               client_rb << ["\n", "use_policyfile true",
                             "versioned_cookbooks true",
                             "policy_document_native_api true",
                             "policy_name #{@config[:policy_name]}",
                             "policy_group local"].join("\n")
             end

             if @config[:appendix_config]
               client_rb << ["\n## --appendix-config", @config[:appendix_config]].join("\n")
             end

             client_rb
           end

           alias :orig_start_chef start_chef
           def start_chef
             if @chef_config[:knife_zero]
               if @config[:bootstrap_converge]
               client_path = @chef_config[:chef_client_path] || 'chef-client'
               s = String.new("#{client_path} -j /etc/chef/first-boot.json")
               s << ' -l debug' if @config[:verbosity] and @config[:verbosity] >= 2
               s << " -E #{bootstrap_environment}" unless bootstrap_environment.nil?
               s << " -S http://127.0.0.1:#{::Knife::Zero::Helper.zero_remote_port}"
               s << " -W" if @config[:why_run]
               Chef::Log.info "Remote command: " + s
               s
               else
                 "echo Execution of Chef-Client has been canceled due to bootstrap_converge is false."
               end
             else
               orig_start_chef
             end
           end

           ## For support policy_document_databag(old style)
           alias :orig_first_boot first_boot
           def first_boot
             attributes = orig_first_boot
             if @config[:policy_name]
               attributes.delete(:run_list)
             end
             attributes
           end
         end
      end
    end
  end
end
