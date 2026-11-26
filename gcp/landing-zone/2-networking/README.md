# 2-networking

The networking stage. It manages the hub and spoke host projects that the workload projects get their networks from.

## What it manages

### Projects

Project IDs are built from `prefix` as described in [ADR 0001](../../../docs/decisions/0001-name-resources-with-prefix-environment-purpose-counter.md). Each project's display name equals its project ID.

| Project | Folder | Purpose |
| --- | --- | --- |
| `<prefix>-prod-net-core-0` | Networking | Hub |
| `<prefix>-dev-net-spoke-0` | Networking/Development | Development spoke |
| `<prefix>-prod-net-spoke-0` | Networking/Production | Production spoke |

The projects are linked to `billing_account`. The organization's org policies stop the default network.

Every host project has the APIs listed in `host_project_services` enabled and is a [Shared VPC host project](https://docs.cloud.google.com/vpc/docs/shared-vpc): projects attached to it as service projects can use its subnets. Removing an API from the list stops Terraform from managing it but leaves it enabled.

### Networks

Each host project has one custom-mode VPC with global dynamic routing and one subnet in `region`, with Private Google Access on. The spoke subnets have secondary ranges reserved for GKE Pods and Services. The ranges of the networks don't overlap, so they can be peered.

| VPC | Project | Subnet | Primary range | Secondary ranges |
| --- | --- | --- | --- | --- |
| `hub-0` | `<prefix>-prod-net-core-0` | `hub-default` | `10.71.0.0/24` | |
| `dev-0` | `<prefix>-dev-net-spoke-0` | `dev-default` | `10.73.0.0/24` | `pods` `10.73.64.0/18`, `services` `10.73.16.0/20` |
| `prod-0` | `<prefix>-prod-net-spoke-0` | `prod-default` | `10.72.0.0/24` | `pods` `10.72.64.0/18`, `services` `10.72.16.0/20` |

### Peering

`hub-0` is peered with `dev-0` and `prod-0` through [VPC Network Peering](https://docs.cloud.google.com/vpc/docs/vpc-peering). A peering is a pair of connections, one created in each network, and becomes active once both exist:

| Connection | Network | Peer network |
| --- | --- | --- |
| `hub-to-dev` | `hub-0` | `dev-0` |
| `dev-to-hub` | `dev-0` | `hub-0` |
| `hub-to-prod` | `hub-0` | `prod-0` |
| `prod-to-hub` | `prod-0` | `hub-0` |

Peered networks always exchange their subnet routes. Every connection also exports and imports custom routes, so static and dynamic routes added to one network later reach its peers, except those with network tags or the default internet gateway as next hop. Peering isn't transitive, so `dev-0` and `prod-0` can't reach each other through `hub-0`.

### NAT

Each VPC has a Cloud Router in `region` with a [Public NAT](https://docs.cloud.google.com/nat/docs/public-nat) gateway, so VMs without external IP addresses can reach the internet. The gateway serves every range of every subnet in the region and allocates its external IP addresses automatically. A gateway can't serve VMs in peered networks ([Cloud NAT product interactions](https://docs.cloud.google.com/nat/docs/nat-product-interactions)), so every VPC has its own.

| VPC | Cloud Router | NAT gateway |
| --- | --- | --- |
| `hub-0` | `hub-router` | `hub-nat` |
| `dev-0` | `dev-router` | `dev-nat` |
| `prod-0` | `prod-router` | `prod-nat` |

### DNS

The hub and each spoke host project have a [private zone](https://docs.cloud.google.com/dns/docs/zones/zones-overview) under `test.`, a top-level domain reserved for testing ([RFC 6761](https://www.rfc-editor.org/rfc/rfc6761)). Each zone holds a `localhost` A record for `127.0.0.1`. A private zone answers only queries from the VPCs it's visible to, so each spoke zone is visible to its own VPC and to `hub-0`.

A [peering zone](https://docs.cloud.google.com/dns/docs/zones/peering-zones) for the root domain `.` sends every query from `dev-0` and `prod-0` to `hub-0`, which resolves it in its own [name resolution order](https://docs.cloud.google.com/dns/docs/vpc-name-res-order): its private zones, then Compute Engine internal DNS, then public DNS. So the spokes resolve all three zones through the hub. DNS peering doesn't depend on VPC Network Peering.

| Zone | Project | DNS name | Kind | Visible to |
| --- | --- | --- | --- | --- |
| `pvt-test` | `<prefix>-prod-net-core-0` | `test.` | Private | `hub-0` |
| `pvt-dev-test` | `<prefix>-dev-net-spoke-0` | `dev.test.` | Private | `dev-0`, `hub-0` |
| `pvt-prod-test` | `<prefix>-prod-net-spoke-0` | `prod.test.` | Private | `prod-0`, `hub-0` |
| `peer-root` | `<prefix>-prod-net-core-0` | `.` | Peering with `hub-0` | `dev-0`, `prod-0` |

### Firewall

Each VPC has the same ingress rules, all with no targets, so they apply to every VM in the network. Firewall rules aren't shared through peering, so each VPC needs its own. The allow rules live in a [global network firewall policy](https://docs.cloud.google.com/firewall/docs/network-firewall-policies) per VPC, named after the VPC and associated with it. The deny rule is a [VPC firewall rule](https://docs.cloud.google.com/firewall/docs/firewalls).

| Rule | Kind | Priority | Action | Sources | Protocols and ports | Logging |
| --- | --- | --- | --- | --- | --- | --- |
| `allow-healthchecks` | Policy | 1001 | Allow | [Health check probe ranges](https://docs.cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges) | TCP 22, 80, and 443 | Off |
| `allow-ssh-from-iap` | Policy | 1002 | Allow | `35.235.240.0/20`, the [IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding) range | TCP 22 | On |
| `allow-icmp` | Policy | 1003 | Allow | `10.0.0.0/8`, `172.16.0.0/12`, and `192.168.0.0/16` | ICMP | Off |
| `ingress-default-deny` | VPC | 65535 | Deny | `0.0.0.0/0` | All | On |

Each VPC sets its [enforcement order](https://docs.cloud.google.com/firewall/docs/firewall-policies-rule-eval-order) to `BEFORE_CLASSIC_FIREWALL`, so the policy is evaluated before the VPC firewall rules. Traffic that no policy rule matches goes on to the VPC rules, where `ingress-default-deny` blocks it. With the default order, the deny rule would block the traffic before the policy is evaluated.

`ingress-default-deny` blocks what the [implied deny ingress rule](https://docs.cloud.google.com/firewall/docs/firewalls#default_firewall_rules) already blocks, but it can be logged and the implied rule can't. [Firewall Rules Logging](https://docs.cloud.google.com/firewall/docs/firewall-policy-rules-logging-overview) writes to the host project's logs; the deny rule logs without metadata fields. Egress is open through the implied allow egress rule.

## Prerequisites

- Terraform 1.17.0 or later.
- [`0-org-setup`](../0-org-setup/) applied: it creates the folders, the stage's service accounts and their roles, and the state managed folder.
- For plans: membership in the `iac_operators` group of `0-org-setup`.

## Configuration

`terraform.tfvars` holds the choices that any deployment can keep: `region` and `host_project_services`.

`prefix` and `billing_account` come from `TF_VAR_*` environment variables. See [Configuration](../README.md#configuration).

`folder_ids` comes from the `0-org-setup` tfvars file. The file holds more values than the stage declares, so Terraform warns about the undeclared ones. See [Values for undeclared variables](https://developer.hashicorp.com/terraform/language/values/variables).

## Running

The state is in the `2-networking` managed folder of the `stage-state` bucket. To plan as `iac-networking-ro`, download its providers file and the `0-org-setup` tfvars file. Only the `0-org-setup` accounts and the CI/CD accounts can read the `outputs` bucket, so download them as `iac-org-ro`:

```sh
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/providers/2-networking-ro-providers.tf . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
gcloud storage cp gs://<prefix>-prod-iac-core-0-outputs/tfvars/0-org-setup.auto.tfvars.json . --impersonate-service-account iac-org-ro@<prefix>-prod-iac-core-0.iam.gserviceaccount.com
terraform init
terraform plan -lock=false
```

## CI/CD

Pull requests that change this stage get a plan, and merges to `main` apply it after approval in the `2-networking` environment. See [CI/CD](../README.md#cicd).
