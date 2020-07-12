#!/usr/bin/env python3.7

import json
import sys
import os

from infraxys_aliyun.helper import AliyunHelper
from infraxys.logger import Logger

from aliyunsdkcore.acs_exception.exceptions import ClientException
from aliyunsdkcore.acs_exception.exceptions import ServerException
from aliyunsdkvpc.request.v20160428 import DescribeVpcsRequest
from aliyunsdkecs.request.v20140526 import DescribeInstancesRequest

class SshGenerator(object):

    def __init__(self, profile_name, target_file, vpc_id=None, vpc_name=None, name_list_json_file=None):
        self.target_file = target_file
        self.vpc_id = vpc_id
        self.vpc_name = vpc_name
        self.name_list_json_file = name_list_json_file
        self.ssh_key_names_file = '/tmp/ssh_key_names.json'
        self.logger = Logger.get_logger(self.__class__.__name__)
        self.client = AliyunHelper.get_client(profile_name=profile_name)
        self.result = ""

    def generate_config(self):
        self.get_vpc()

        if not self.vpc_id:
            print(
                "VPC '" + self.vpc_name + "' not found. This is not necessarily a problem because it might not have been created yet.")
            return ""

        instances = self.get_instances(vpc_id=self.vpc_id)
        non_bastion_instances = []
        multi_instance_names = []
        instance_names = []
        bastion_instance = None
        bastion_name = ""
        instance_details_json = {}
        ssh_keys_by_instance_name = {}
        for instance in instances:
            instance_name = instance['InstanceName']
            if not instance_name:  # ignore instances that don't have a name
                continue

            if not "KeyPairName" in instance:
                continue

            if not instance_name in ssh_keys_by_instance_name:
                ssh_keys_by_instance_name[instance_name] = '{}.pem'.format(instance["KeyPairName"])

            if "bastion" in instance_name.lower():
                bastion_instance = instance
                bastion_name = instance_name
                instance_details_json[instance_name] = []
                instance_details_json[instance_name].append(self.get_instance_details(bastion_name, instance))
            else:
                if instance_name in instance_names:
                    multi_instance_names.append(instance_name)
                else:
                    instance_details_json[instance_name] = []

                instance_names.append(instance_name)
                non_bastion_instances.append(instance)

        if not bastion_instance:
            raise Exception("No instance with 'bastion' in the name found in this vpc.")

        key_filename = "~/.ssh/keys/{}.pem".format(bastion_instance["KeyPairName"])
        instance_counter = {}

        self.result = """Host {}
    Hostname {}
    User ubuntu
    IdentityFile "{}"                    
                    """.format(bastion_name, bastion_instance["PublicIpAddress"]["IpAddress"][0], key_filename)

        proxy_command = 'ProxyCommand ssh {} -W %h:%p'.format(bastion_name)
        for instance in non_bastion_instances:
            key_filename = "~/.ssh/keys/{}.pem".format(instance["KeyPairName"])
            instance_name = instance['InstanceName']
            real_instance_name = instance_name
            if instance_name in multi_instance_names:
                if instance_name in instance_counter.keys():
                    counter = instance_counter[instance_name] + 1
                else:
                    counter = 1

                instance_counter[instance_name] = counter
                instance_name = "{}-{}".format(instance_name, counter)

            #print("Adding {} to {}".format(instance_name, real_instance_name))

            instance_details_json[real_instance_name].append(
                self.get_instance_details(instance_name, instance))
            instance_private_ip = instance["PrivateIpAddress"]

            self.result = """{}
       
Host {}
   Hostname {}
   User ubuntu
   {}
   IdentityFile {}
            """.format(self.result, instance_name, instance_private_ip, proxy_command, key_filename)

        if self.name_list_json_file:
            with open(self.name_list_json_file, 'w', encoding='utf-8') as f:
                json.dump(instance_details_json, f, ensure_ascii=False, indent=2)

        with open(self.ssh_key_names_file, 'w', encoding='utf-8') as f:
            json.dump(ssh_keys_by_instance_name, f, ensure_ascii=False, indent=2)

        with open(self.target_file, 'w', encoding='utf-8') as f:
            f.write(self.result)



    def get_instance_details(self, hostname, instance):
        jsonObject = {
            'hostname': hostname,
            'privateIpAddress': instance['VpcAttributes']['PrivateIpAddress']['IpAddress'][0],
            'keyName': instance['KeyPairName']
        }
        return jsonObject

    def get_vpc(self):
        if not self.vpc_id:
            if not self.vpc_name:
                raise Exception("vpc_id nor vpc_name set.")

            self.vpc_id = self.get_vpc_id(vpc_name=self.vpc_name)

    def get_vpc_id(self, vpc_name):
        self.logger.info(f'Retrieving VPC {vpc_name}')
        request = DescribeVpcsRequest.DescribeVpcsRequest()
        request.set_VpcName(vpc_name)
        request.set_accept_format('json')
        request.set_PageSize(50)
        vpcs_json = json.loads(self.client.do_action_with_exception(request), encoding='utf-8')
        return vpcs_json['Vpcs']['Vpc'][0]['VpcId']

    def get_instances(self, vpc_id):
        self.logger.info(f'Retrieving instances for VPC {vpc_id}')
        request = DescribeInstancesRequest.DescribeInstancesRequest()
        request.set_VpcId(vpc_id)
        request.set_PageSize(100)
        instances_json = json.loads(self.client.do_action_with_exception(request), encoding='utf-8')
        return instances_json['Instances']['Instance']

    def get_name_tag_value(self, json_object):
        if "Tags" in json_object:
            for tag in json_object["Tags"]:
                if tag["Key"].lower() == "name":
                    return tag["Value"]

        return None

if __name__ == "__main__":
    profile_name=sys.argv[1]
    vpc_name = sys.argv[2]
    target_file = sys.argv[3]
    name_list_json_file = None
    if len(sys.argv) > 3:
        name_list_json_file = sys.argv[4]

    generator = SshGenerator(profile_name=profile_name, vpc_name=vpc_name, target_file=target_file, name_list_json_file=name_list_json_file)
    result = generator.generate_config()
    #print(result)
