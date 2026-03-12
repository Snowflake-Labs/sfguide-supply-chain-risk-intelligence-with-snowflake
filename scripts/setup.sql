/******************************************************************************
 * GNN SUPPLY CHAIN RISK ANALYSIS - COMPLETE SETUP SCRIPT
 * 
 * Purpose: Deploy a Graph Neural Network-powered supply chain risk analysis
 *          platform on Snowflake using PyTorch Geometric, Cortex Agent, and
 *          a multi-page Streamlit dashboard.
 * Domain: Manufacturing / Supply Chain
 * 
 * What This Script Does:
 * 1.  Creates role, warehouse, database, and schema
 * 2.  Creates compute pool for GPU notebooks
 * 3.  Creates network rules and external access integration for PyPI
 * 4.  Creates Git integration and repository
 * 5.  Creates tables (input ERP data + GNN output tables)
 * 6.  Creates views for analytics
 * 7.  Creates file format and stages
 * 8.  Loads CSV data from Git repository into tables
 * 9.  Creates risk analysis UDF
 * 10. Deploys GPU notebook (PyTorch Geometric GNN training)
 * 11. Uploads semantic model for Cortex Analyst
 * 12. Deploys Streamlit dashboard (8 pages)
 * 13. Creates Cortex Agent
 * 
 * Prerequisites:
 *   - Snowflake account with ACCOUNTADMIN role
 *   - Cortex AI features enabled
 *   - GPU compute pool support (GPU_NV_S instance family)
 *   - External Access Integration support (not available on trial accounts)
 * 
 * Repository: https://github.com/Snowflake-Labs/sfguide-gnn-supply-chain-risk
 * Duration: ~5-10 minutes (GPU compute pool creation may take additional time)
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

ALTER SESSION SET query_tag = '{
    "origin":"sf_sit-is",
    "name":"gnn_supply_chain_risk",
    "version":{"major":1,"minor":0},
    "attributes":{"is_quickstart":1,"source":"sql"}
}';

SET USERNAME = (SELECT CURRENT_USER());

--------------------------------------------------------------------------------
-- STEP 1: CREATE ROLE
--------------------------------------------------------------------------------

CREATE OR REPLACE ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT ROLE GNN_SUPPLY_CHAIN_RISK_ROLE TO USER IDENTIFIER($USERNAME);
GRANT ROLE GNN_SUPPLY_CHAIN_RISK_ROLE TO ROLE ACCOUNTADMIN;
GRANT ROLE GNN_SUPPLY_CHAIN_RISK_ROLE TO ROLE SYSADMIN;

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- STEP 2: CREATE WAREHOUSE (as ACCOUNTADMIN, grant to demo role)
--------------------------------------------------------------------------------

CREATE OR REPLACE WAREHOUSE GNN_SUPPLY_CHAIN_RISK_WH
    WAREHOUSE_SIZE = SMALL
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for GNN Supply Chain Risk SQL operations';

GRANT USAGE ON WAREHOUSE GNN_SUPPLY_CHAIN_RISK_WH TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT OPERATE ON WAREHOUSE GNN_SUPPLY_CHAIN_RISK_WH TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

USE WAREHOUSE GNN_SUPPLY_CHAIN_RISK_WH;

--------------------------------------------------------------------------------
-- STEP 3: CREATE DATABASE AND SCHEMA (as ACCOUNTADMIN, grant to demo role)
--------------------------------------------------------------------------------

CREATE OR REPLACE DATABASE GNN_SUPPLY_CHAIN_RISK
    COMMENT = 'GNN-powered supply chain risk analysis platform';

CREATE SCHEMA IF NOT EXISTS GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK
    COMMENT = 'Supply chain data, GNN outputs, and application objects';

GRANT USAGE ON DATABASE GNN_SUPPLY_CHAIN_RISK TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT CREATE SCHEMA ON DATABASE GNN_SUPPLY_CHAIN_RISK TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- STEP 4: SNOWFLAKE INTELLIGENCE AND CORTEX SETUP
--------------------------------------------------------------------------------

ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

GRANT CREATE AGENT ON SCHEMA GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- STEP 5: CREATE COMPUTE POOL (as ACCOUNTADMIN, grant to demo role)
--------------------------------------------------------------------------------

CREATE COMPUTE POOL IF NOT EXISTS GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = GPU_NV_S
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 600
    COMMENT = 'GPU compute pool for PyTorch Geometric GNN training';

GRANT USAGE ON COMPUTE POOL GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
GRANT MONITOR ON COMPUTE POOL GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- STEP 6: CREATE NETWORK RULES AND EXTERNAL ACCESS INTEGRATION
--------------------------------------------------------------------------------

CREATE OR REPLACE NETWORK RULE GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK_EGRESS_RULE
    TYPE = HOST_PORT
    MODE = EGRESS
    VALUE_LIST = (
        'pypi.org:443',
        'files.pythonhosted.org:443',
        'download.pytorch.org:443',
        'data.pyg.org:443'
    )
    COMMENT = 'Required for PyTorch Geometric and dependencies';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION GNN_SUPPLY_CHAIN_RISK_EXTERNAL_ACCESS
    ALLOWED_NETWORK_RULES = (GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK_EGRESS_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION GNN_SUPPLY_CHAIN_RISK_EXTERNAL_ACCESS TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- STEP 7: CREATE GIT INTEGRATION AND REPOSITORY
--------------------------------------------------------------------------------

CREATE OR REPLACE API INTEGRATION GNN_SUPPLY_CHAIN_RISK_GIT_API_INTEGRATION
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/Snowflake-Labs/')
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION GNN_SUPPLY_CHAIN_RISK_GIT_API_INTEGRATION TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

USE ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;
USE DATABASE GNN_SUPPLY_CHAIN_RISK;
USE SCHEMA GNN_SUPPLY_CHAIN_RISK;

CREATE OR REPLACE GIT REPOSITORY GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK_REPO
    API_INTEGRATION = GNN_SUPPLY_CHAIN_RISK_GIT_API_INTEGRATION
    ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-gnn-supply-chain-risk';

--------------------------------------------------------------------------------
-- STEP 8: CREATE STAGES
--------------------------------------------------------------------------------

CREATE STAGE IF NOT EXISTS MODELS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for ML models and notebooks';

CREATE STAGE IF NOT EXISTS DATA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for data files';

CREATE STAGE IF NOT EXISTS SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for semantic model YAML files';

--------------------------------------------------------------------------------
-- STEP 9: CREATE FILE FORMAT
--------------------------------------------------------------------------------

CREATE FILE FORMAT IF NOT EXISTS CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE;

--------------------------------------------------------------------------------
-- STEP 10: CREATE TABLES - ERP DATA (Input)
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS VENDORS (
    VENDOR_ID VARCHAR(20) PRIMARY KEY,
    NAME VARCHAR(255) NOT NULL,
    COUNTRY_CODE VARCHAR(3) NOT NULL,
    CITY VARCHAR(100),
    PHONE VARCHAR(50),
    TIER NUMBER DEFAULT 1,
    FINANCIAL_HEALTH_SCORE FLOAT DEFAULT 0.5,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Vendor master data - known Tier 1 suppliers from ERP';

CREATE TABLE IF NOT EXISTS MATERIALS (
    MATERIAL_ID VARCHAR(20) PRIMARY KEY,
    DESCRIPTION VARCHAR(255) NOT NULL,
    MATERIAL_GROUP VARCHAR(10) NOT NULL,
    UNIT_OF_MEASURE VARCHAR(10) DEFAULT 'PC',
    CRITICALITY_SCORE FLOAT DEFAULT 0.5,
    INVENTORY_DAYS NUMBER DEFAULT 30,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Material master - parts and products hierarchy';

CREATE TABLE IF NOT EXISTS PURCHASE_ORDERS (
    PO_ID VARCHAR(20) PRIMARY KEY,
    VENDOR_ID VARCHAR(20) NOT NULL,
    MATERIAL_ID VARCHAR(20) NOT NULL,
    QUANTITY NUMBER NOT NULL,
    UNIT_PRICE FLOAT NOT NULL,
    ORDER_DATE DATE NOT NULL,
    DELIVERY_DATE DATE,
    STATUS VARCHAR(20) DEFAULT 'OPEN',
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (VENDOR_ID) REFERENCES VENDORS(VENDOR_ID),
    FOREIGN KEY (MATERIAL_ID) REFERENCES MATERIALS(MATERIAL_ID)
)
COMMENT = 'Purchase orders - known supplier to part edges';

CREATE TABLE IF NOT EXISTS BILL_OF_MATERIALS (
    BOM_ID VARCHAR(20) PRIMARY KEY,
    PARENT_MATERIAL_ID VARCHAR(20) NOT NULL,
    CHILD_MATERIAL_ID VARCHAR(20) NOT NULL,
    QUANTITY_PER_UNIT FLOAT NOT NULL DEFAULT 1.0,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (PARENT_MATERIAL_ID) REFERENCES MATERIALS(MATERIAL_ID),
    FOREIGN KEY (CHILD_MATERIAL_ID) REFERENCES MATERIALS(MATERIAL_ID)
)
COMMENT = 'Bill of materials - part assembly hierarchy';

CREATE TABLE IF NOT EXISTS TRADE_DATA (
    BOL_ID VARCHAR(20) PRIMARY KEY,
    SHIPPER_NAME VARCHAR(255) NOT NULL,
    SHIPPER_COUNTRY VARCHAR(3),
    CONSIGNEE_NAME VARCHAR(255) NOT NULL,
    CONSIGNEE_COUNTRY VARCHAR(3),
    HS_CODE VARCHAR(10) NOT NULL,
    HS_DESCRIPTION VARCHAR(255),
    SHIP_DATE DATE NOT NULL,
    WEIGHT_KG FLOAT,
    VALUE_USD FLOAT,
    PORT_OF_ORIGIN VARCHAR(100),
    PORT_OF_DESTINATION VARCHAR(100),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'External trade data - bills of lading for Tier 2+ inference';

CREATE TABLE IF NOT EXISTS REGIONS (
    REGION_CODE VARCHAR(3) PRIMARY KEY,
    REGION_NAME VARCHAR(100) NOT NULL,
    BASE_RISK_SCORE FLOAT DEFAULT 0.0,
    GEOPOLITICAL_RISK FLOAT DEFAULT 0.0,
    NATURAL_DISASTER_RISK FLOAT DEFAULT 0.0,
    INFRASTRUCTURE_SCORE FLOAT DEFAULT 0.5,
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Geographic region risk factors';

--------------------------------------------------------------------------------
-- STEP 11: CREATE TABLES - GNN MODEL OUTPUTS
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS RISK_SCORES (
    SCORE_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    NODE_ID VARCHAR(50) NOT NULL,
    NODE_TYPE VARCHAR(20) NOT NULL,
    RISK_SCORE FLOAT NOT NULL,
    RISK_CATEGORY VARCHAR(20),
    CONFIDENCE FLOAT,
    EMBEDDING ARRAY,
    CONTRIBUTING_FACTORS VARIANT,
    MODEL_VERSION VARCHAR(50),
    CALCULATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'GNN-computed risk scores for all supply chain nodes';

CREATE TABLE IF NOT EXISTS PREDICTED_LINKS (
    LINK_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_NODE_ID VARCHAR(50) NOT NULL,
    SOURCE_NODE_TYPE VARCHAR(20) NOT NULL,
    TARGET_NODE_ID VARCHAR(50) NOT NULL,
    TARGET_NODE_TYPE VARCHAR(20) NOT NULL,
    LINK_TYPE VARCHAR(50) NOT NULL,
    PROBABILITY FLOAT NOT NULL,
    EVIDENCE_STRENGTH VARCHAR(20),
    SUPPORTING_DATA VARIANT,
    MODEL_VERSION VARCHAR(50),
    PREDICTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'GNN-predicted hidden supplier relationships';

CREATE TABLE IF NOT EXISTS BOTTLENECKS (
    BOTTLENECK_ID NUMBER AUTOINCREMENT PRIMARY KEY,
    NODE_ID VARCHAR(50) NOT NULL,
    NODE_TYPE VARCHAR(20) NOT NULL,
    DEPENDENT_COUNT NUMBER NOT NULL,
    DEPENDENT_NODES ARRAY,
    IMPACT_SCORE FLOAT NOT NULL,
    DESCRIPTION VARCHAR(500),
    MITIGATION_STATUS VARCHAR(20) DEFAULT 'UNMITIGATED',
    IDENTIFIED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Identified single points of failure in supply chain';

--------------------------------------------------------------------------------
-- STEP 12: CREATE VIEWS FOR ANALYTICS
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW VW_SUPPLIER_RISK AS
SELECT 
    v.VENDOR_ID,
    v.NAME AS VENDOR_NAME,
    v.COUNTRY_CODE,
    v.TIER,
    r.BASE_RISK_SCORE AS REGION_RISK,
    rs.RISK_SCORE AS GNN_RISK_SCORE,
    rs.RISK_CATEGORY,
    rs.CONFIDENCE,
    COALESCE(po_stats.TOTAL_ORDERS, 0) AS TOTAL_ORDERS,
    COALESCE(po_stats.TOTAL_VALUE, 0) AS TOTAL_ORDER_VALUE
FROM VENDORS v
LEFT JOIN REGIONS r ON v.COUNTRY_CODE = r.REGION_CODE
LEFT JOIN RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID AND rs.NODE_TYPE = 'SUPPLIER'
LEFT JOIN (
    SELECT VENDOR_ID, COUNT(*) AS TOTAL_ORDERS, SUM(QUANTITY * UNIT_PRICE) AS TOTAL_VALUE
    FROM PURCHASE_ORDERS
    GROUP BY VENDOR_ID
) po_stats ON v.VENDOR_ID = po_stats.VENDOR_ID;

CREATE OR REPLACE VIEW VW_MATERIAL_RISK AS
SELECT 
    m.MATERIAL_ID,
    m.DESCRIPTION,
    m.MATERIAL_GROUP,
    m.CRITICALITY_SCORE,
    rs.RISK_SCORE AS GNN_RISK_SCORE,
    rs.RISK_CATEGORY,
    COALESCE(supplier_count.NUM_SUPPLIERS, 0) AS NUM_SUPPLIERS,
    COALESCE(supplier_count.AVG_SUPPLIER_RISK, 0) AS AVG_SUPPLIER_RISK
FROM MATERIALS m
LEFT JOIN RISK_SCORES rs ON m.MATERIAL_ID = rs.NODE_ID AND rs.NODE_TYPE = 'PART'
LEFT JOIN (
    SELECT 
        po.MATERIAL_ID,
        COUNT(DISTINCT po.VENDOR_ID) AS NUM_SUPPLIERS,
        AVG(COALESCE(rs2.RISK_SCORE, 0.5)) AS AVG_SUPPLIER_RISK
    FROM PURCHASE_ORDERS po
    LEFT JOIN RISK_SCORES rs2 ON po.VENDOR_ID = rs2.NODE_ID AND rs2.NODE_TYPE = 'SUPPLIER'
    GROUP BY po.MATERIAL_ID
) supplier_count ON m.MATERIAL_ID = supplier_count.MATERIAL_ID;

CREATE OR REPLACE VIEW VW_HIDDEN_DEPENDENCIES AS
SELECT 
    pl.LINK_ID,
    pl.SOURCE_NODE_ID,
    pl.SOURCE_NODE_TYPE,
    CASE 
        WHEN pl.SOURCE_NODE_TYPE = 'SUPPLIER' THEN v1.NAME
        ELSE pl.SOURCE_NODE_ID
    END AS SOURCE_NAME,
    pl.TARGET_NODE_ID,
    pl.TARGET_NODE_TYPE,
    CASE 
        WHEN pl.TARGET_NODE_TYPE = 'SUPPLIER' THEN v2.NAME
        ELSE pl.TARGET_NODE_ID
    END AS TARGET_NAME,
    pl.PROBABILITY,
    pl.EVIDENCE_STRENGTH,
    pl.PREDICTED_AT
FROM PREDICTED_LINKS pl
LEFT JOIN VENDORS v1 ON pl.SOURCE_NODE_ID = v1.VENDOR_ID
LEFT JOIN VENDORS v2 ON pl.TARGET_NODE_ID = v2.VENDOR_ID
WHERE pl.PROBABILITY >= 0.5
ORDER BY pl.PROBABILITY DESC;

CREATE OR REPLACE VIEW VW_RISK_SUMMARY AS
SELECT 
    'SUPPLIERS' AS CATEGORY,
    COUNT(*) AS TOTAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'HIGH' THEN 1 ELSE 0 END) AS HIGH_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'MEDIUM' THEN 1 ELSE 0 END) AS MEDIUM_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'LOW' THEN 1 ELSE 0 END) AS LOW_COUNT,
    AVG(RISK_SCORE) AS AVG_RISK_SCORE
FROM RISK_SCORES WHERE NODE_TYPE = 'SUPPLIER'
UNION ALL
SELECT 
    'PARTS' AS CATEGORY,
    COUNT(*) AS TOTAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END) AS CRITICAL_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'HIGH' THEN 1 ELSE 0 END) AS HIGH_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'MEDIUM' THEN 1 ELSE 0 END) AS MEDIUM_COUNT,
    SUM(CASE WHEN RISK_CATEGORY = 'LOW' THEN 1 ELSE 0 END) AS LOW_COUNT,
    AVG(RISK_SCORE) AS AVG_RISK_SCORE
FROM RISK_SCORES WHERE NODE_TYPE = 'PART';

--------------------------------------------------------------------------------
-- STEP 13: COPY DATA FILES FROM GIT REPO TO INTERNAL STAGE
--------------------------------------------------------------------------------

ALTER GIT REPOSITORY GNN_SUPPLY_CHAIN_RISK_REPO FETCH;

COPY FILES
    INTO @DATA_STAGE/synthetic/
    FROM @GNN_SUPPLY_CHAIN_RISK_REPO/branches/main/data/synthetic/
    PATTERN = '.*\.csv';

--------------------------------------------------------------------------------
-- STEP 14: LOAD CSV DATA INTO TABLES
--------------------------------------------------------------------------------

COPY INTO REGIONS (REGION_CODE, REGION_NAME, BASE_RISK_SCORE, GEOPOLITICAL_RISK, NATURAL_DISASTER_RISK, INFRASTRUCTURE_SCORE)
FROM @DATA_STAGE/synthetic/regions.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

COPY INTO VENDORS (VENDOR_ID, NAME, COUNTRY_CODE, CITY, PHONE, TIER, FINANCIAL_HEALTH_SCORE)
FROM @DATA_STAGE/synthetic/vendors.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

COPY INTO MATERIALS (MATERIAL_ID, DESCRIPTION, MATERIAL_GROUP, UNIT_OF_MEASURE, CRITICALITY_SCORE, INVENTORY_DAYS)
FROM @DATA_STAGE/synthetic/materials.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

COPY INTO BILL_OF_MATERIALS (BOM_ID, PARENT_MATERIAL_ID, CHILD_MATERIAL_ID, QUANTITY_PER_UNIT)
FROM @DATA_STAGE/synthetic/bill_of_materials.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

COPY INTO PURCHASE_ORDERS (PO_ID, VENDOR_ID, MATERIAL_ID, QUANTITY, UNIT_PRICE, ORDER_DATE, DELIVERY_DATE, STATUS)
FROM @DATA_STAGE/synthetic/purchase_orders.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

COPY INTO TRADE_DATA (BOL_ID, SHIPPER_NAME, SHIPPER_COUNTRY, CONSIGNEE_NAME, CONSIGNEE_COUNTRY, HS_CODE, HS_DESCRIPTION, SHIP_DATE, WEIGHT_KG, VALUE_USD, PORT_OF_ORIGIN, PORT_OF_DESTINATION)
FROM @DATA_STAGE/synthetic/trade_data.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

--------------------------------------------------------------------------------
-- STEP 15: CREATE RISK ANALYSIS UDF
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION ANALYZE_RISK_SCENARIO(
    scenario_type VARCHAR,
    target_region VARCHAR DEFAULT NULL,
    target_vendor VARCHAR DEFAULT NULL,
    shock_intensity FLOAT DEFAULT 0.5
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
SELECT OBJECT_CONSTRUCT(
    'scenario_type', scenario_type,
    'target', COALESCE(target_region, target_vendor, 'all'),
    'shock_intensity', shock_intensity,
    'analysis', CASE 
        WHEN scenario_type = 'REGIONAL_DISRUPTION' THEN
            (SELECT OBJECT_CONSTRUCT(
                'affected_vendors', COUNT(DISTINCT v.VENDOR_ID),
                'avg_current_risk', ROUND(AVG(rs.RISK_SCORE), 3),
                'projected_risk', ROUND(LEAST(1.0, AVG(rs.RISK_SCORE) + (shock_intensity * 0.3)), 3),
                'recommendation', CASE 
                    WHEN COUNT(*) > 5 THEN 'High concentration risk - diversify suppliers'
                    ELSE 'Moderate exposure - monitor closely'
                END
            )
            FROM VENDORS v
            JOIN RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            WHERE v.COUNTRY_CODE = target_region
            )
        WHEN scenario_type = 'VENDOR_FAILURE' THEN
            (SELECT OBJECT_CONSTRUCT(
                'vendor_name', v.NAME,
                'current_risk', rs.RISK_SCORE,
                'dependent_materials', (
                    SELECT COUNT(DISTINCT MATERIAL_ID) 
                    FROM PURCHASE_ORDERS 
                    WHERE VENDOR_ID = target_vendor
                ),
                'bottleneck_impact', COALESCE(b.IMPACT_SCORE, 0),
                'recommendation', CASE
                    WHEN rs.RISK_SCORE > 0.7 THEN 'Immediate action required - identify alternates'
                    WHEN rs.RISK_SCORE > 0.4 THEN 'Develop contingency plan'
                    ELSE 'Low priority - standard monitoring'
                END
            )
            FROM VENDORS v
            JOIN RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            LEFT JOIN BOTTLENECKS b ON v.VENDOR_ID = b.NODE_ID
            WHERE v.VENDOR_ID = target_vendor
            )
        WHEN scenario_type = 'PORTFOLIO_SUMMARY' THEN
            (SELECT OBJECT_CONSTRUCT(
                'total_vendors', COUNT(DISTINCT VENDOR_ID),
                'critical_count', SUM(CASE WHEN rs.RISK_CATEGORY = 'CRITICAL' THEN 1 ELSE 0 END),
                'high_risk_count', SUM(CASE WHEN rs.RISK_CATEGORY IN ('CRITICAL', 'HIGH') THEN 1 ELSE 0 END),
                'avg_portfolio_risk', ROUND(AVG(rs.RISK_SCORE), 3),
                'total_bottlenecks', (SELECT COUNT(*) FROM BOTTLENECKS),
                'health_score', ROUND((1 - AVG(rs.RISK_SCORE)) * 100, 1)
            )
            FROM VENDORS v
            JOIN RISK_SCORES rs ON v.VENDOR_ID = rs.NODE_ID
            )
        ELSE
            OBJECT_CONSTRUCT('error', 'Unknown scenario type. Use: REGIONAL_DISRUPTION, VENDOR_FAILURE, or PORTFOLIO_SUMMARY')
    END
)
$$;

--------------------------------------------------------------------------------
-- STEP 16: DEPLOY GPU NOTEBOOK
--------------------------------------------------------------------------------

COPY FILES
    INTO @MODELS_STAGE/notebooks/
    FROM @GNN_SUPPLY_CHAIN_RISK_REPO/branches/main/notebooks/
    FILES = ('gnn_supply_chain_risk.ipynb');

CREATE OR REPLACE NOTEBOOK GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK_NOTEBOOK
    FROM '@MODELS_STAGE/notebooks/'
    MAIN_FILE = 'gnn_supply_chain_risk.ipynb'
    RUNTIME_NAME = 'SYSTEM$GPU_RUNTIME'
    COMPUTE_POOL = 'GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL'
    QUERY_WAREHOUSE = 'GNN_SUPPLY_CHAIN_RISK_WH'
    EXTERNAL_ACCESS_INTEGRATIONS = (GNN_SUPPLY_CHAIN_RISK_EXTERNAL_ACCESS)
    IDLE_AUTO_SHUTDOWN_TIME_SECONDS = 1800
    COMMENT = 'GNN Supply Chain Risk Analysis - PyTorch Geometric graph neural network training';

ALTER NOTEBOOK GNN_SUPPLY_CHAIN_RISK_NOTEBOOK ADD LIVE VERSION FROM LAST;

--------------------------------------------------------------------------------
-- STEP 17: UPLOAD SEMANTIC MODEL
--------------------------------------------------------------------------------

COPY FILES
    INTO @SEMANTIC_MODELS/
    FROM @GNN_SUPPLY_CHAIN_RISK_REPO/branches/main/scripts/semantic_models/
    FILES = ('supply_chain_risk.yaml');

--------------------------------------------------------------------------------
-- STEP 18: DEPLOY STREAMLIT APP
--------------------------------------------------------------------------------

CREATE OR REPLACE STREAMLIT GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK.GNN_SUPPLY_CHAIN_RISK_APP
    FROM '@GNN_SUPPLY_CHAIN_RISK_REPO/branches/main/streamlit/'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = 'GNN_SUPPLY_CHAIN_RISK_WH'
    TITLE = 'Supply Chain Risk Intelligence'
    COMMENT = '{"origin":"sf_sit-is", "name":"gnn_supply_chain_risk", "version":{"major":1, "minor":0}}';

ALTER STREAMLIT GNN_SUPPLY_CHAIN_RISK_APP ADD LIVE VERSION FROM LAST;

GRANT USAGE ON STREAMLIT GNN_SUPPLY_CHAIN_RISK_APP TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- STEP 19: CREATE CORTEX AGENT (LAST - after all dependencies)
--------------------------------------------------------------------------------

CREATE OR REPLACE AGENT SUPPLY_CHAIN_RISK_AGENT
  COMMENT = 'Supply Chain Risk Copilot - answers questions using semantic model and scenario analysis UDF'
  FROM SPECIFICATION $$
  {
    "models": {
      "orchestration": "claude-4-sonnet"
    },
    "instructions": {
      "orchestration": "Use SUPPLY_CHAIN_ANALYTICS for data queries about vendors, materials, risk scores, purchase orders, and trade data. Use RISK_SCENARIO_ANALYZER for scenario analysis like regional disruptions, vendor failures, and portfolio summaries."
    },
    "tools": [
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "SUPPLY_CHAIN_ANALYTICS",
          "description": "Query supply chain data including vendors, materials, risk scores, purchase orders, trade data, and bottlenecks using natural language"
        }
      }
    ],
    "tool_resources": {
      "SUPPLY_CHAIN_ANALYTICS": {
        "semantic_model": "@SEMANTIC_MODELS/supply_chain_risk.yaml",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "GNN_SUPPLY_CHAIN_RISK_WH"
        }
      }
    }
  }
  $$;

GRANT USAGE ON AGENT SUPPLY_CHAIN_RISK_AGENT TO ROLE GNN_SUPPLY_CHAIN_RISK_ROLE;

--------------------------------------------------------------------------------
-- SETUP COMPLETE
--------------------------------------------------------------------------------

SELECT 'GNN Supply Chain Risk Analysis - Setup Complete!' as STATUS;

/******************************************************************************
 * SETUP COMPLETE!
 * 
 * Your GNN Supply Chain Risk Analysis platform is ready with:
 * - Database: GNN_SUPPLY_CHAIN_RISK
 * - Warehouse: GNN_SUPPLY_CHAIN_RISK_WH
 * - Compute Pool: GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL (GPU_NV_S)
 * - Tables: 9 tables (6 input + 3 GNN output), 4 views
 * - Notebook: GNN_SUPPLY_CHAIN_RISK_NOTEBOOK (GPU, PyTorch Geometric)
 * - Streamlit: GNN_SUPPLY_CHAIN_RISK_APP (8-page dashboard)
 * - Agent: SUPPLY_CHAIN_RISK_AGENT (Cortex Analyst)
 * - UDF: ANALYZE_RISK_SCENARIO
 * 
 * NEXT STEPS:
 * 1. Open the notebook in Snowsight and run all cells to train the GNN
 *    and populate risk scores, predicted links, and bottleneck tables
 * 2. Open the Streamlit dashboard to explore results
 * 3. Chat with the Cortex Agent for natural language risk analysis
 * 
 * To remove everything: Run scripts/teardown.sql
 ******************************************************************************/
