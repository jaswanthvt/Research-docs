Below is a detailed report based on our conversation about RAN slicing in 5G O-RAN, focusing on the interaction between the Network Slice Management Function (NSMF) and the Service Management and Orchestration (SMO) framework, how SMO processes NSSI profiles to create RAN slices, and specific examples like priority, non-priority, and isolated defense slices. Key parts are highlighted in bold for emphasis. The report includes references to standards and resources discussed throughout.

---

# Report: RAN Slicing in 5G O-RAN: NSMF to SMO Interaction and Implementation

## Introduction
RAN slicing in 5G Open Radio Access Network (O-RAN) enables the creation of virtualized radio access networks tailored to diverse use cases, such as robotics, streaming, and defense operations, on shared physical infrastructure. The **Network Slice Management Function (NSMF)** defines end-to-end network slices and delegates RAN-specific subnet management to the **Service Management and Orchestration (SMO)** framework, which acts as the RAN Network Slice Subnet Management Function (NSSMF). This report details the data NSMF provides to SMO, how SMO processes this data to instantiate RAN slices, and the logic involved, with a focus on three example slices: a priority robotics slice (URLLC), a non-priority streaming slice (eMBB), and an isolated defense slice (URLLC). It also explores implementation resources and references key standards like 3GPP TS 28.541.

## 1. What NSMF Provides to SMO

### NSSI Profile Overview
NSMF sends SMO a **Network Slice Subnet Instance (NSSI) profile** for the RAN domain, as defined in **3GPP TS 28.541** (Section 6.3.3). This profile contains parameters specifying the slice subnet’s identity, performance requirements, resource needs, and operational details. These parameters enable SMO to configure and manage RAN components (e.g., O-CU, O-DU, O-RU) effectively.

### Parameters from 3GPP TS 28.541
Below is a comprehensive list of NSSI attributes from TS 28.541, with examples for our three use cases:

| **Parameter**                | **Description**                                                                                         | **Example: Priority Robotics (URLLC)**         | **Example: Non-Priority Streaming (eMBB)**     | **Example: Isolated Defense (URLLC)**          |
|------------------------------|---------------------------------------------------------------------------------------------------------|-----------------------------------------------|-----------------------------------------------|-----------------------------------------------|
| **id**                       | Unique NSSI identifier                                                         | “NSSI_RAN_Robotics1”                         | “NSSI_RAN_Streaming1”                        | “NSSI_RAN_Defense1”                          |
| **nsiId**                    | Parent NSI identifier                                                          | “NSI_Robotics”                               | “NSI_Streaming”                              | “NSI_Defense”                                |
| **sliceType**                | SST and SD defining slice purpose                                              | SST=1, SD=“Factory Robotics”                 | SST=2, SD=“Public Streaming”                 | SST=1, SD=“Defense Ops”                      |
| **latency**                  | Target latency in ms                                                           | 1 ms                                         | 20 ms                                        | 2 ms                                         |
| **dLThptPerSliceSubnet**     | Downlink throughput in Mbps                                                    | 100 Mbps                                     | 500 Mbps                                     | 50 Mbps                                      |
| **maxNumberOfUEs**           | Maximum UEs supported                                                          | 150                                          | 10,000                                       | 75                                           |
| **priorityLabel**            | Priority level                                                                 | 1 (high)                                     | 3 (low)                                      | 2 (high)                                     |
| **resourceSharingLevel**     | Resource sharing (shared/dedicated)                                            | “shared”                                     | “shared”                                     | “dedicated”                                  |
| **coverageAreaList**         | Geographic coverage                                                            | “Cell IDs 101-103”                           | “Cell IDs 201-205”                           | “Cell IDs 301-302”                           |
| **qosFlowList**              | QoS flows with 5QI values                                                      | QFI=1, 5QI=1                                 | QFI=2, 5QI=9                                 | QFI=3, 5QI=2                                 |
| **managedFunctionList**      | Network functions and resources                                                | O-CU-CP (2 vCPUs), O-DU (1 vCPU)             | O-CU-CP (4 vCPUs), O-DU (2 vCPUs)            | O-CU-CP (2 vCPUs), O-CU-UP (1 vCPU), O-DU (1 vCPU) |

- **Key Insight:** The NSSI profile is a blueprint that SMO uses to tailor the RAN slice, with parameters like `latency`, `priorityLabel`, and `resourceSharingLevel` driving resource allocation and isolation decisions.

## 2. How SMO Processes NSSI Profiles

### SMO Components and Roles
SMO comprises:
- **Non-Real-Time RAN Intelligent Controller (Non-RT RIC):** Interprets NSSI data, makes strategic decisions, and sets policies using AI/ML.
- **OAM (Operations, Administration, and Maintenance):** Configures RAN components via O1.
- **NFV Orchestration (e.g., OS MANO):** Deploys virtual network functions (VNFs) via O2.

The **Non-RT RIC** is the primary decision-maker, processing NSSI profiles to instantiate RAN slices.

### Processing Logic
SMO’s logic, executed by Non-RT RIC, involves:

1. **Parsing NSSI Profile:**
   - Extracts parameters like `sliceType`, `latency`, and `qosFlowList`.
   - Example: For robotics, “1 ms latency” signals a high-priority URLLC slice.

2. **Resource Assessment:**
   - Queries OAM (O1) for available PRBs and vCPUs.
   - Example: Ensures Edge Cloud A has 15% PRBs for robotics.

3. **SLA Prioritization:**
   - Prioritizes based on `priorityLabel` and `sliceType` (e.g., URLLC > eMBB).
   - Example: Robotics (Priority 1) optimizes for latency, streaming (Priority 3) for throughput.

4. **Deployment Decision:**
   - Selects edge (low latency) or regional (high capacity) clouds based on `latency` and `coverageAreaList`.
   - Example: Robotics and defense at edge, streaming at regional.

5. **NFV Orchestration:**
   - Uses OS MANO (O2) to deploy VNFs (e.g., O-CU, O-DU), respecting `resourceSharingLevel`.
   - Example: Defense slice gets a dedicated O-CU-UP.

6. **Configuration:**
   - Configures RAN components via O1 with PRB allocations and QoS flows.
   - Example: Robotics O-DU gets 15% PRBs, 5QI=1.

7. **Optimization:**
   - Sends policies to Near-RT RIC (A1) for real-time adjustments.
   - Example: “Scale PRBs if latency > 1 ms” for robotics.

8. **Monitoring:**
   - Tracks performance via O1/E2 to ensure SLA compliance.

### Pseudo-Code Logic
```python
def process_nssi_profile(nssi):
    # Parse profile
    slice_type = nssi["sliceProfileList"]["sliceType"]
    latency = nssi["sliceProfileList"]["latency"]
    throughput = nssi["sliceProfileList"]["dLThptPerSliceSubnet"]
    priority = nssi["sliceProfileList"]["priorityLabel"]
    resources = nssi["managedFunctionList"]
    isolation = nssi["resourceSharingLevel"]
    coverage = nssi["coverageAreaList"]

    # Assess resources
    available = query_oam_resources()
    if not (available["prbs"] >= resources["radio"] and available["vCPUs"] >= resources["compute"]):
        return "Resource Error"

    # Prioritize SLA
    if priority <= 2 or latency < 5:
        optimize_for = "latency"
    else:
        optimize_for = "throughput"

    # Decide deployment
    location = "edge" if latency < 5 else "regional"

    # Orchestrate VNFs
    vnf_config = {"location": location, "resources": resources, "isolation": isolation}
    send_o2_request(vnf_config)

    # Configure RAN
    configure_o1({"prbs": resources["radio"], "qos": nssi["qosFlowList"]})

    # Optimize
    policies = {"optimize": optimize_for, "threshold": latency}
    send_a1_policies(policies)

    return "Slice Created"
```

- **Key Insight:** This logic ensures SMO translates NSSI data into actionable RAN configurations, balancing priority and isolation.

## 3. Example: Processing Three Slice Subnets

### Scenario Setup
- **Priority Robotics (URLLC):** 1 ms latency, 100 Mbps, 15% PRBs, edge deployment.
- **Non-Priority Streaming (eMBB):** 20 ms latency, 500 Mbps, 30% PRBs, regional deployment.
- **Isolated Defense (URLLC):** 2 ms latency, 50 Mbps, 10% PRBs, isolated resources, edge deployment.
- **Infrastructure:** Edge Cloud A (10 vCPUs, 50% PRBs), Regional Cloud B (20 vCPUs, 80% PRBs), Edge Cloud C (8 vCPUs, 30% PRBs).

### Processing Details
1. **Robotics Slice:**
   - **Parse:** `latency`=1 ms, `priorityLabel`=1 → optimize for latency.
   - **Resources:** 3 vCPUs, 15% PRBs available at Edge Cloud A.
   - **Deployment:** Edge Cloud A.
   - **Orchestration:** O-CU-CP (2 vCPUs), O-DU (1 vCPU).
   - **Config:** 15% PRBs, 5QI=1.
   - **Result:** 1 ms latency, 100 Mbps.

2. **Streaming Slice:**
   - **Parse:** `latency`=20 ms, `priorityLabel`=3 → optimize for throughput.
   - **Resources:** 6 vCPUs, 30% PRBs at Regional Cloud B.
   - **Deployment:** Regional Cloud B.
   - **Orchestration:** O-CU-CP (4 vCPUs), O-DU (2 vCPUs).
   - **Config:** 30% PRBs, 5QI=9.
   - **Result:** 500 Mbps, 18 ms latency.

3. **Defense Slice:**
   - **Parse:** `latency`=2 ms, `resourceSharingLevel`=“dedicated” → isolated, latency-focused.
   - **Resources:** 4 vCPUs, 10% PRBs at Edge Cloud C.
   - **Deployment:** Edge Cloud C.
   - **Orchestration:** O-CU-CP (2 vCPUs), dedicated O-CU-UP (1 vCPU), O-DU (1 vCPU).
   - **Config:** 10% PRBs, 5QI=2.
   - **Result:** 2 ms latency, 50 Mbps, isolated.

- **Key Insight:** SMO’s ability to handle priority (robotics), capacity (streaming), and isolation (defense) showcases its versatility.

## 4. Implementation Resources

### Papers
- **“End-to-End Network Slice Architecture” (EURASIP, 2021):** Details OSM-based orchestration, applicable to SMO’s O2 role ([jwcn-eurasipjournals.springeropen.com/articles/10.1186/s13638-021-02002-6](https://jwcn-eurasipjournals.springeropen.com/articles/10.1186/s13638-021-02002-6)).
- **“Slice-Aware 5G Network Orchestration” (Nature, 2023):** Explores isolation strategies, relevant to defense slice ([www.nature.com/articles/s41598-023-50150-2](https://www.nature.com/articles/s41598-023-50150-2)).
- **“Intelligent Admission in O-RAN” (IEEE, 2022):** Uses DRL for SMO optimization, aligning with Non-RT RIC ([ieeexplore.ieee.org/document/9844089](https://ieeexplore.ieee.org/document/9844089)).

### Videos
- **O-RAN Alliance Webinars:** PlugFest demos (e.g., 2023) may show SMO workflows ([www.o-ran.org/events](https://www.o-ran.org/events)).
- **ONAP Tutorials:** Network slicing with SMO integration ([www.onap.org](https://www.onap.org)).

### GitHub
- **O-RAN SC SMO:** Tools for slice orchestration ([github.com/o-ran-sc/smo](https://github.com/o-ran-sc/smo)).
- **ONAP Network Slicing:** Scripts for NSMF-SMO interaction ([github.com/onap/integration-usecases/tree/master/network-slicing](https://github.com/onap/integration-usecases/tree/master/network-slicing)).
- **ETSI OSM:** NFV orchestration for SMO ([github.com/etsi-osm/OSM](https://github.com/etsi-osm/OSM)).

- **Key Insight:** These resources provide partial implementations, requiring customization to fully replicate the NSMF-to-SMO process.

## 5. Conclusion
The NSMF-to-SMO interaction in O-RAN RAN slicing is a sophisticated process where NSMF provides a detailed NSSI profile (per TS 28.541), and SMO, led by Non-RT RIC, processes it into functional RAN slices. The logic balances priority, resource allocation, and isolation, as demonstrated by the robotics, streaming, and defense examples. Implementation resources like OSM and O-RAN SC offer practical starting points, though full end-to-end solutions may require integration. This process exemplifies O-RAN’s flexibility in meeting diverse 5G demands.

## References
1. **3GPP TS 28.541 V17.0.0 (2022-03):** Management and Orchestration; 5G Network Resource Model (NRM) ([3GPP TS 28.541](https://www.3gpp.org/ftp/Specs/2022-03/Rel-17/28541-d00.zip)).
2. **3GPP TS 28.530 V17.0.0 (2022-03):** Management and Orchestration; Concepts ([3GPP TS 28.530](https://www.3gpp.org/ftp/Specs/2022-03/Rel-17/28530-d00.zip)).
3. **O-RAN WG1 Slicing Architecture V05.00 (2021):** O-RAN Slicing Guidelines ([O-RAN.WG1.Slicing-Architecture-v05.00](https://www.scribd.com/document/550869220/O-RAN-wg1-Slicing-Architecture-v05-00-1)).
4. **O-RAN Alliance:** General Resources and WG3 RIC Details ([www.o-ran.org](https://www.o-ran.org/)).
5. **ETSI GS NFV-MAN 001 (2014):** NFV Management and Orchestration ([www.etsi.org/deliver/etsi_gs/NFV-MAN/001_099/001/01.01.01_60/gs_NFV-MAN001v010101p.pdf](https://www.etsi.org/deliver/etsi_gs/NFV-MAN/001_099/001/01.01.01_60/gs_NFV-MAN001v010101p.pdf)).

---

This report consolidates our conversation, emphasizing **NSSI profiles**, **SMO’s Non-RT RIC logic**, and **example-driven execution**, with references grounding it in authoritative standards and resources. Let me know if you need adjustments or additional sections!
