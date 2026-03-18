# Fiber (PON) Network Concepts

A quick reference for OSS/BSS integration developers using the Cambium Fiber API.

You do **not** need to understand fiber hardware in depth to use the API.
This document explains the concepts that matter most when provisioning subscribers and services.

---

## OLT - Optical Line Terminal

The **OLT** is the fiber access controller, typically installed at the service provider's central office or headend.

It connects the service provider's upstream network to many subscriber devices over a shared passive optical network (PON). Cambium Fiber OLTs are 8-port or 16-port systems, and each port typically serves 32 to 64 subscribers per port through passive optical splitters (although technically capable of 128 GPON and 128 XGS-PON (256 ONUs per port)).

Think of the OLT as the **access switch for dozens to hundreds of fiber subscribers**. It manages subscriber devices in a way that is similar to how a switch manages access ports.

The Cambium Fiber API communicates with multiple OLTs and handles the transport, authentication, and provisioning logic around them. In Cambium Fiber API, each entry in `connections.json` represents one physical OLT. Shared authentication templating and virtual stacking are used to reduce repeated configuration across a site.

---

## ONU / ONT - Subscriber Fiber Endpoint

An **ONU** is the subscriber-side device at the customer premises.

It converts the fiber connection into Ethernet for the customer's router, gateway, access point, or other downstream device.

You may also see the term **ONT**. In practice, ONU and ONT are close enough that most integration work can treat them the same way. For Cambium Fiber documentation, it is simplest to think of:

- **ONU** = the general subscriber-side PON endpoint
- **ONT** = a common single-Ethernet-port subtype of ONU

Each ONU can expose **two different serial numbers**, and mixing them up causes provisioning mistakes:

- **PON SN** or **PON serial number** = the standards-based identifier used by the PON system
- **MSN** or **manufacturer serial number** = the vendor manufacturing identifier used for one-time OLT onboarding into cnMaestro, not for Cambium Fiber API ONU management

For GPON and XGS-PON, the important identifier for PON management is the **PON SN (Serial Number)**. Its format is defined by the standards and consists of a 4-character manufacturer identifier followed by 8 hexadecimal digits (`0-9`, `A-F`). For Cambium-manufactured ONUs, that PON serial number begins with `CMBM`. For example:

```text
CMBM000000C0
```

In Cambium deployments, ONUs are auto-onboarded when they connect to an OLT unless this behavior is disabled by using the whitelist feature. For the **Cambium Fiber API**, the only serial number that matters for ONU management, whether the ONU is Cambium or third-party, is the **PON SN**.

The **MSN** is relevant to one-time **OLT** onboarding into cnMaestro, but it is not used by the **Cambium Fiber API** for ONU identification or management.

Unless a field is explicitly labeled otherwise, treat any `serial` in the Cambium Fiber API as referring to the **PON serial number**.

The Cambium Fiber API represents ONUs with these fields:

| API field | Meaning |
|-----------|--------|
| `serial` | PON serial number — the primary identifier used throughout the API |
| `name` | Human-readable label (e.g. subscriber name) |
| `index` | OLT-local registration ID — useful operationally but not a durable cross-OLT identifier |
| `profile_id` | Assigned ONU profile ID |
| `dl_speed` | Current maximum downlink speed in Mbps |
| `ul_speed` | Current maximum uplink speed in Mbps |
| `param_mask` | Bitmask indicating which parameters are explicitly overridden on this ONU |
| `status` | Real-time ONU status (online, offline, etc.) |

> **Fixture vs API field names:** The raw OLT config and fixture files use hyphenated names (`onu-serial-number`, `onu-max-dl-speed`, `onu-profile`). The API translates these into the cleaner field names above. When editing fixtures, use the fixture names; when calling the API, use the API names.

---

## ONU Profile

An **ONU profile** is the template that defines the subscriber package.

Examples:

- Residential 500 Mbps
- Residential 1 Gbps
- Business Internet
- Triple Play package

An ONU profile usually defines:

- Maximum download speed
- Maximum upload speed
- Default service profile bindings
- Other ONU defaults such as management profile or frame size

Key ideas:

- Profiles represent **packages the ISP sells**
- Assigning a different profile changes the subscriber tier
- Profiles are defined per OLT and reused across many ONUs

Rate limits are highly recommended because they help the OLT schedule traffic correctly and prevent it from sending traffic to an ONU faster than the ONU's Ethernet interface can forward it preventing (bufferboloat).

---

## Service Profile

A **service profile** defines how subscriber traffic is transported through the access network.

For developers, the most important part is usually the **VLAN mapping**.

Service profiles are configured on the OLT, then assigned to ONUs directly or indirectly through an ONU profile.

### The Four VLAN Values

At the OLT configuration level, service profiles use a set of **four VLAN fields**:

- **C-VLAN in** (upstream of the ONU)
- **S-VLAN in** (upstream of the ONU)
- **C-VLAN out** (Downstream of the ONU)
- **S-VLAN out** (Downstream of the ONU)

These mean:

| Field | Meaning |
|------|------|
| `c_vlan_in` | Customer VLAN used for **upstream traffic (subscriber → provider)** |
| `c_vlan_out` | Customer VLAN used for **downstream traffic (provider → subscriber)** |
| `s_vlan_in` | Service-provider VLAN used for **upstream traffic** (`null` when unused) |
| `s_vlan_out` | Service-provider VLAN used for **downstream traffic** (`null` when unused) |

> **Note:** These fields are on the **service profile object** stored on the OLT. The Cambium Fiber API's ONU service endpoint (`GET /provisioning/devices/onu/service/{serial}`) returns only `id`, `name`, and `interface` for each binding — not the VLAN details. VLAN configuration is managed at the OLT level, not per-ONU via the API.

### C-VLAN

A **C-VLAN** is a normal **802.1Q VLAN tag**.

This is the standard VLAN tag most developers already know, and in most deployments it is the VLAN that matters.

### S-VLAN

An **S-VLAN** is a **service-provider VLAN tag**, used as the **outer tag** in **802.1ad Q-in-Q** VLAN stacking.

This is used when a provider carries customer VLAN-tagged traffic inside another provider VLAN (less common).

Unless you are specifically using **802.1ad Q-in-Q**, you should usually think of S-VLAN as **unused**.

### VLAN In vs VLAN Out

The **in** and **out** fields describe VLAN handling on the **ONU service flow** for ingress versus egress.

A simple way to think about it:

- **`*-in`** = the tag value used for traffic entering the service from the **ONU/subscriber side** toward the network
- **`*-out`** = the tag value used for traffic leaving the service toward the **ONU/subscriber side** after processing or translation

This allows the ONU service handling to:

- pass a VLAN unchanged
- strip a VLAN
- add a VLAN
- translate one VLAN to another
- wrap customer VLAN traffic inside a service-provider VLAN for Q-in-Q

### Common Cases

#### 1. Normal access VLAN service

Typical residential or business internet service. Set `c_vlan_in` to the subscriber's VLAN. Leave S-VLAN fields unset. This is the common case.

#### 2. VLAN passthrough

Set matching `c_vlan_in` and `c_vlan_out` values. The VLAN tag passes through unchanged. Useful for VoIP or other tagged service VLANs.

#### 3. Q-in-Q trunk service

Set an S-VLAN to wrap customer VLAN traffic inside a service-provider VLAN. A specialized deployment, not the usual one.

---

## Fixture Format vs API Format

The fixture files (raw OLT config) use hyphenated field names. The Cambium Fiber API normalises everything to snake_case. The values and semantics are identical — only the key names differ.

| Fixture key | API field |
|-------------|----------|
| `onu-serial-number` | `serial` |
| `onu-max-dl-speed` | `dl_speed` |
| `onu-max-ul-speed` | `ul_speed` |
| `onu-profile` | `profile_id` |
| `maximum-downlink-speed` | `maximum_downlink_speed` |
| `maximum-uplink-speed` | `maximum_uplink_speed` |
| `service-profile` | `service_profile` |
| `c-vlan-in` | `c_vlan_in` |
| `c-vlan-out` | `c_vlan_out` |
| `s-vlan-in` | `s_vlan_in` |
| `s-vlan-out` | `s_vlan_out` |

When editing fixtures, use the fixture names. When calling or reading the API, use the API names.

---

## How These Pieces Fit Together

```text
OLT
 └── ONU
      └── ONU Profile
           └── Service Profile(s)
```

Example:

```text
OLT
 └── ONU (subscriber device)
      └── ONU Profile: Residential Gold
           └── Service Profile: Residential Internet
```

Typical provisioning flow:

1. The ONU is discovered or pre-provisioned by serial number.
2. An ONU profile is assigned to match the subscriber package.
3. The ONU receives the correct service profile bindings.
4. Traffic is carried on the expected VLANs at the expected speeds.

---

## Mock OLT Fixture Files

In the **Cambium Fiber Mock OLT**, each file in `fixtures/` is a full starting configuration for one OLT.

Fixtures typically include:

- ONU profiles
- Service profiles
- Existing ONUs
- Management settings
- System configuration

Editing a fixture changes the mock OLT's starting state the next time the container starts.

This is useful for:

- pre-loading test subscribers
- creating test service tiers
- modeling VLAN service behavior
- testing provisioning and sync flows

Runtime changes made through the API are stored in memory only. Restarting the container resets the OLT back to the fixture baseline.
