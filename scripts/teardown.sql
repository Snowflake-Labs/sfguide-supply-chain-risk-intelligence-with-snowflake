/******************************************************************************
 * GNN SUPPLY CHAIN RISK ANALYSIS - TEARDOWN SCRIPT
 * 
 * Purpose: Remove all demo resources
 * 
 * WARNING: This permanently deletes:
 *   - Database GNN_SUPPLY_CHAIN_RISK (all data, tables, views, stages, notebooks)
 *   - Warehouse GNN_SUPPLY_CHAIN_RISK_WH
 *   - Compute Pool GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL
 *   - External Access Integration GNN_SUPPLY_CHAIN_RISK_EXTERNAL_ACCESS
 *   - Git API Integration GNN_SUPPLY_CHAIN_RISK_GIT_API_INTEGRATION
 *   - Role GNN_SUPPLY_CHAIN_RISK_ROLE
 * 
 * Run as ACCOUNTADMIN to ensure all objects removed.
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS GNN_SUPPLY_CHAIN_RISK;

DROP WAREHOUSE IF EXISTS GNN_SUPPLY_CHAIN_RISK_WH;

DROP COMPUTE POOL IF EXISTS GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL;

DROP INTEGRATION IF EXISTS GNN_SUPPLY_CHAIN_RISK_EXTERNAL_ACCESS;

DROP INTEGRATION IF EXISTS GNN_SUPPLY_CHAIN_RISK_GIT_API_INTEGRATION;

DROP ROLE IF EXISTS GNN_SUPPLY_CHAIN_RISK_ROLE;

SELECT 'Cleanup complete!' as STATUS;

/******************************************************************************
 * VERIFY CLEANUP
 ******************************************************************************/

SHOW DATABASES LIKE 'GNN_SUPPLY_CHAIN_RISK';
SHOW WAREHOUSES LIKE 'GNN_SUPPLY_CHAIN_RISK_WH';
SHOW COMPUTE POOLS LIKE 'GNN_SUPPLY_CHAIN_RISK_COMPUTE_POOL';
SHOW ROLES LIKE 'GNN_SUPPLY_CHAIN_RISK_ROLE';
