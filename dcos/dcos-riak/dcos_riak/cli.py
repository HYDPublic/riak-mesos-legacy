#
#    Copyright (C) 2015 Basho Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""DCOS Riak"""
from __future__ import print_function

import os
import subprocess
import sys
import requests
import json

import pkg_resources
from dcos import marathon, util
from dcos_riak import constants

def usage():
    print("dcos riak <subcommand> [<options>]")
    print("Subcommands: ")
    print("    --get-clusters")
    print("    --get-cluster <cluster-name>")
    print("    --create-cluster <cluster-name>")
    print("    --get-nodes <cluster-name>")
    print("    --add-node <cluster-name>")
    print("    --info")
    print("    --version")
    print("Options: ")
    print("    --framework-name <framework-name>")
    print("    --debug")

def maybe_debug(flag, r):
    if flag == 1:
        print("[DEBUG]\n")
        print("Status: "+ str(r.status_code))
        print("Text: "+ r.text)
        print("[/DEBUG]")

def api_url(name):
    client = marathon.create_client()
    tasks = client.get_tasks(name)

    if len(tasks) == 0:
        usage()
        print("\nTry running the following to verify that "+ name + " is the name \nof your service instance:\n")
        print("    dcos service\n")
        raise CliError("Riak is not running, try with --framework-name <framework-name>.")

    base_url = util.get_config().get('core.dcos_url').rstrip("/")
    return base_url + "/service/" + name + "/"

def validate_arg(opt, arg):
    if arg.startswith("-"):
        raise CliError("Invalid argument for opt: " + opt + " [" + arg + "].")

def format_json_array_keys(description, json_str, failure):
    try:
        obj_arr = json.loads(json_str)
        print(description + "[" + ', '.join(obj_arr.keys()) + "]", end="")
    except:
        print(description + failure)

def format_json_value(description, json_str, key, failure):
    try:
        obj = json.loads(json_str)
        print(description + obj[key], end="")
    except:
        print(description + failure)

def get_clusters(service_url, flag):
    r = requests.get(service_url + "clusters")
    maybe_debug(flag, r)
    if r.status_code == 200:
        format_json_array_keys("Clusters: ", r.text, "[]")
    else:
        print("No clusters created")

def get_cluster(service_url, name, flag):
    r = requests.get(service_url + "clusters/" + name)
    maybe_debug(flag, r)
    if r.status_code == 200:
        format_json_value("Cluster: ", r.text, "Name", "Error getting cluster.")
    else:
        print("Cluster not created.")

def create_cluster(service_url, name, flag):
    r = requests.post(service_url + "clusters/" + name, data="")
    maybe_debug(flag, r)
    if r.text == "" or r.status_code != 200:
        print("Cluster already exists")
    else:
        format_json_value("Added cluster: ", r.text, "Name", "Error creating cluster.")

def get_nodes(service_url, name, flag):
    r = requests.get(service_url + "clusters/" + name + "/nodes")
    maybe_debug(flag, r)
    format_json_array_keys("Nodes: ", r.text, "[]")

def add_node(service_url, name, flag):
    r = requests.post(service_url + "clusters/" + name + "/nodes", data="")
    maybe_debug(flag, r)
    if r.status_code == 404:
        print(r.text)
    else:
        format_json_value("New node: ", r.text, "UUID", "Error adding node.")

def run(args):
    help_arg = 0
    flag = 0
    service_url = ""

    if "--help" in args or "-h" in args:
        help_arg = 1

    if "--debug" in args:
        flag = 1

    if help_arg:
        usage()
        return 0

    if "--info" in args and "--framework-name" not in args:
        print("Start and manage Riak nodes")
        return 0

    if "--version" in args:
        print(constants.version)
        return 0

    if "--config-schema" in args:
        print("{}")
        return 0

    if "--framework-name" in args and args.index('--framework-name')+1 < len(args):
        name = args[args.index('--framework-name')+1]
        validate_arg("--framework-name", name)
        service_url = api_url(name)
    else:
        service_url = api_url("riak")

    if "--info" in args:
        print("Start and manage Riak nodes")
        print("Service URL: " + service_url)
        return 0

    for i, opt in enumerate(args):
        if opt == "--get-clusters":
            get_clusters(service_url, flag)
            break
        elif opt == "--get-cluster":
            if i+1 < len(args):
                validate_arg(opt, args[i+1])
                get_cluster(service_url, args[i+1], flag)
                print("")
                get_nodes(service_url, args[i+1], flag)
            else:
                usage()
            break
        elif opt == "--get-nodes":
            if i+1 < len(args):
                validate_arg(opt, args[i+1])
                get_nodes(service_url, args[i+1], flag)
            else:
                usage()
            break
        elif opt == "--create-cluster":
            if i+1 < len(args):
                validate_arg(opt, args[i+1])
                create_cluster(service_url, args[i+1], flag)
            else:
                usage()
            break
        elif opt == "--add-node":
            if i+1 < len(args):
                validate_arg(opt, args[i+1])
                add_node(service_url, args[i+1], flag)
            else:
                usage()
            break
        elif opt == "--framework-name":
            continue
        elif not opt.startswith("-"):
            continue
        else:
            usage()
            print("")
            raise CliError("Unrecognized option: " + opt)

    print("")

    return 0


class CliError(Exception):
    pass


def main():
    args = sys.argv[2:]  # remove dcos-riak & riak
    if len(args) == 0:
        usage()
        return 0

    try:
        return run(args)
    except CliError as e:
        print("Error: " + str(e), file=sys.stderr)
        return 1