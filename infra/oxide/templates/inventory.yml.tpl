---
k3s_cluster:
  children:
    server:
      hosts:
%{ for ip in slice(node_ips, 0, server_count) }
        ${ip}:
%{ endfor }
    agent:
      hosts:
%{ for ip in slice(node_ips, server_count, length(node_ips)) }
        ${ip}:
%{ endfor }
  vars:
    ansible_port: 22
    ansible_user: ubuntu
    k3s_version: v1.30.2+k3s1
    token: "changeme!"
