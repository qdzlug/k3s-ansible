k3s_cluster:
  children:
    server:
      hosts:
%{ for i in range(server_count) ~}
        ${node_ips[i]}: {}
%{ endfor ~}
    agent:
      hosts:
%{ for i in range(server_count, length(node_ips)) ~}
        ${node_ips[i]}: {}
%{ endfor ~}

  vars:
    ansible_port: 22
    ansible_user: ${ansible_user}
    k3s_version: "${k3s_version}"
    token: "${k3s_token}"
    api_endpoint: "{{ hostvars[groups['server'][0]].ansible_default_ipv4.address }}"
    extra_server_args: "--tls-san {{ hostvars[groups['server'][0]].ansible_default_ipv4.address }} --tls-san {{ hostvars[groups['server'][0]]['ansible_host'] | default(groups['server'][0]) }}"

lb:
  hosts:
    ${nginx_lb_ip}:
      traefik_backend_host: ${traefik_backend_ip}
