# GNN Supply Chain Risk Analysis

Detect hidden supply chain vulnerabilities using Graph Neural Networks (PyTorch Geometric) on Snowflake with GPU-accelerated notebooks, Cortex Agent, and a multi-page Streamlit dashboard.

## Overview

Modern supply chains have deep, opaque dependencies beyond Tier 1 suppliers. This solution builds a heterogeneous graph from ERP data (vendors, materials, purchase orders, bill of materials) and external trade intelligence (bills of lading), then trains a GraphSAGE model to:

- **Propagate risk** through the supply network using GNN message passing
- **Predict hidden links** between Tier 2+ suppliers via link prediction
- **Identify bottlenecks** — single points of failure in the supply chain

**Key capabilities:**
- **GNN Risk Scoring** — GraphSAGE-based risk propagation across heterogeneous supply chain graph
- **Hidden Dependency Detection** — Link prediction reveals unknown Tier 2+ supplier relationships
- **Natural Language Risk Analysis** — Cortex Agent with semantic model for conversational supply chain queries
- **8-Page Interactive Dashboard** — Executive summary, network visualization, scenario simulation, and mitigation planning

## Prerequisites

- Snowflake account with ACCOUNTADMIN role
- GPU compute pool support (GPU_NV_S instance family)
- External Access Integration support (**not available on trial accounts**)
- Cortex AI features enabled

> **Note on Privileges:** This guide uses ACCOUNTADMIN for simplicity in demo and learning environments. For production deployments, follow the principle of least privilege by creating a dedicated role with only the specific grants required.

> **Note on Trial Accounts:** External Access Integration (EAI) is required for installing PyTorch Geometric in the GPU notebook. Trial accounts do not support EAI. Use a non-trial account for this quickstart.

## Quick Start

### Step 1: Run Setup

1. Open Snowsight: **Projects** → **Worksheets**
2. Click **+** to create a new SQL worksheet
3. Copy the entire contents of [`scripts/setup.sql`](scripts/setup.sql)
4. Paste and click **Run All**

> **Note:** Setup takes ~5 minutes. The GPU compute pool may require additional startup time on first use.

### Step 2: Run the GNN Notebook

The notebook must be run manually to train the GNN and populate output tables:

1. Switch to role `GNN_SUPPLY_CHAIN_RISK_ROLE`
2. Navigate in Snowsight: **Projects** → **Notebooks** → `GNN_SUPPLY_CHAIN_RISK_NOTEBOOK`
3. Click **Run All** to execute all cells

The notebook will:
- Install PyTorch Geometric via pip (requires EAI)
- Build a heterogeneous graph from the loaded data
- Train a GraphSAGE model for risk propagation
- Train a link prediction model for hidden dependency discovery
- Identify bottleneck nodes
- Write results to RISK_SCORES, PREDICTED_LINKS, and BOTTLENECKS tables

### Step 3: Access the Dashboard

Navigate in Snowsight:

1. Switch to role `GNN_SUPPLY_CHAIN_RISK_ROLE`
2. **Projects** → **Streamlit** → `GNN_SUPPLY_CHAIN_RISK_APP`

The dashboard has 8 pages:

| Page | Description |
|------|-------------|
| **Executive Summary** | High-level risk overview with KPIs and health score |
| **Exploratory Analysis** | Deep-dive into vendor and material risk distributions |
| **Supply Network** | Interactive graph visualization of the supply chain |
| **Tier 2 Analysis** | Predicted hidden dependencies and evidence strength |
| **Scenario Simulator** | What-if analysis for regional disruptions and vendor failures |
| **Command Center** | Cortex Agent chat for natural language risk queries |
| **Risk Mitigation** | Prioritized action items and mitigation strategies |
| **About** | Architecture and methodology documentation |

### Step 4: Chat with the Agent

Navigate in Snowsight:

1. Switch to role `GNN_SUPPLY_CHAIN_RISK_ROLE`
2. **AI & ML** → **Cortex Agent** → `SUPPLY_CHAIN_RISK_AGENT`

Sample questions:
- "Which vendors have the highest risk scores?"
- "What is the average risk by country?"
- "How many bottlenecks were identified?"
- "Show me the top 5 critical suppliers"

## What Gets Created

| Object | Name |
|--------|------|
| Database | `GNN_SUPPLY_CHAIN_RISK` |
| Schema | `GNN_SUPPLY_CHAIN_RISK` |
| Warehouse | `GNN_SUPPLY_CHAIN_RISK_WH` (SMALL) |
| Role | `GNN_SUPPLY_CHAIN_RISK_ROLE` |
| Compute Pool | `GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL` (GPU_NV_S) |
| Tables | 6 input + 3 output = 9 tables |
| Views | 4 analytics views |
| Notebook | [`GNN_SUPPLY_CHAIN_RISK_NOTEBOOK`](notebooks/gnn_supply_chain_risk.ipynb) |
| Streamlit | `GNN_SUPPLY_CHAIN_RISK_APP` (8 pages) |
| Agent | `SUPPLY_CHAIN_RISK_AGENT` |
| UDF | `ANALYZE_RISK_SCENARIO` |
| Semantic Model | `@SEMANTIC_MODELS/supply_chain_risk.yaml` |
| External Access | `GNN_SUPPLY_CHAIN_RISK_EXTERNAL_ACCESS` (PyPI) |
| Network Rule | `GNN_SUPPLY_CHAIN_RISK_EGRESS_RULE` |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Data Sources                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Vendors  │  │Materials │  │  Orders  │  │  Trade   │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       └──────────────┴──────────────┴──────────────┘        │
│                         │                                    │
│              ┌──────────▼──────────┐                        │
│              │   GPU Notebook      │                        │
│              │  PyTorch Geometric  │                        │
│              │  GraphSAGE + Link   │                        │
│              │     Prediction      │                        │
│              └──────────┬──────────┘                        │
│                         │                                    │
│       ┌─────────────────┼─────────────────┐                │
│       ▼                 ▼                 ▼                │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────┐          │
│  │Risk Scores│  │Predicted Links│  │ Bottlenecks │          │
│  └────┬─────┘  └──────┬───────┘  └──────┬──────┘          │
│       └────────────────┴─────────────────┘                  │
│                        │                                     │
│         ┌──────────────┼──────────────┐                     │
│         ▼              ▼              ▼                     │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐              │
│  │ Streamlit  │ │  Cortex    │ │   Views   │              │
│  │ Dashboard  │ │   Agent    │ │ Analytics │              │
│  └────────────┘ └────────────┘ └───────────┘              │
└─────────────────────────────────────────────────────────────┘
```

## Cleanup

1. Open Snowsight: **Projects** → **Worksheets**
2. Click **+** to create a new SQL worksheet
3. Copy contents of [`scripts/teardown.sql`](scripts/teardown.sql)
4. Paste and click **Run All**

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "External access integration not supported" | Use a non-trial Snowflake account |
| Compute pool stuck in STARTING | Wait 5-10 minutes; GPU pools take time to provision |
| Notebook pip install fails | Verify EAI is active: `SHOW INTEGRATIONS LIKE 'GNN%'` |
| Streamlit app shows empty data | Run the notebook first to populate output tables |
| Agent returns no results | Ensure semantic model is uploaded and tables have data |

## Conclusion

You now have a complete GNN-powered supply chain risk analysis platform on Snowflake:
- A trained GraphSAGE model scoring risk across your supply network
- Hidden Tier 2+ supplier relationships uncovered via link prediction
- An interactive 8-page dashboard for risk exploration and mitigation
- A natural language Cortex Agent for conversational risk analysis

This demonstrates how Snowflake's GPU notebooks, Cortex AI, and Streamlit combine to deliver end-to-end ML-driven supply chain intelligence.

## License

Copyright (c) Snowflake Inc. All rights reserved.

The code in this repository is licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).
