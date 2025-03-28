---
k3s_cluster:
  children:
    server:
      hosts:
        172.21.252.101:
        172.21.252.105:
        172.21.252.104:
    agent:
      hosts:
  vars:
    ansible_port: 22
    ansible_user: ubuntu
    k3s_version: v1.30.2+k3s1
    token: "changeme!"