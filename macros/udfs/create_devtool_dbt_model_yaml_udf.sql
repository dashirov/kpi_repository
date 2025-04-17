{% macro create_devtool_dbt_model_yaml_udf() %}
{#
     Generates dbt model YAML file content

     deployment
        `dbt dbt-operation create_devtool_dbt_model_yaml_udf`
     scope
        * UDF is deployed to database and schema the user is connected to
        * sandboxed to the database the UDF is deployed in
 #}
{% set sql %}
    CREATE OR REPLACE FUNCTION DEVTOOL_DBT_MODEL_YAML(SCHEMA_NAME VARCHAR, MODEL_NAME_PREFIX VARCHAR, TABLE_NAME_PREFIX VARCHAR)
       RETURNS STRING
       LANGUAGE JAVASCRIPT
    AS
    $$
        function reorderDict(obj) {
            const orderedKeys = ["name", "description", "database", "schema"];
            const primitiveKeys = [];
            const dictKeys = [];
            const listKeys = [];
            const otherKeys = [];

        // Categorize keys
            for (const key in obj) {
                const value = obj[key];
                if (orderedKeys.includes(key)) continue;
                if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
                    primitiveKeys.push(key);
        } else if (Array.isArray(value)) {
                    listKeys.push(key);
        } else if (typeof value === "object") {
                    dictKeys.push(key);
        } else {
                    otherKeys.push(key);
        }
            }

            const orderedObj = {};
            orderedKeys.forEach((key) => {
                if (key in obj) orderedObj[key] = obj[key];
            });
            primitiveKeys.forEach((key) => {
                orderedObj[key] = obj[key];
            });
            dictKeys.forEach((key) => {
                orderedObj[key] = reorderDict(obj[key]);
            });
            listKeys.forEach((key) => {
                orderedObj[key] = obj[key].map((item) => (typeof item === "object" ? reorderDict(item) : item));
            });
            otherKeys.forEach((key) => {
                orderedObj[key] = obj[key];
            });

        return orderedObj;
        }

        function formatValue(value) {
            if (typeof value === 'string') {
                if (value === '' || value.match(/[\n:#\-\{\}\[\],&\*\?]|^\s|\s$|^$/)) {
                    return '"' + value.replace(/"/g, '\\"') + '"'; // quote the string
                } else {
                    return value;
                }
            } else if (typeof value === 'number' || typeof value === 'boolean') {
                return value.toString();
            } else if (value === null) {
                return 'null';
            } else {
                return '';
            }
        }

        function jsonToYaml(obj, indentLevel = 0, inArray = false) {
            const indent = '  '.repeat(indentLevel);
            let yaml = '';
            if (Array.isArray(obj)) {
                for (const item of obj) {
                    if (typeof item === 'object' && item !== null) {
                        // Serialize the item with indentLevel + 1, inArray = true
                        const itemYaml = jsonToYaml(item, indentLevel + 1, true);
                        // Add the '-' and append the item's YAML representation
                        yaml += `${indent}- ${itemYaml}\n`;
                    } else {
                        yaml += `${indent}- ${formatValue(item)}\n`;
                    }
                }
            } else if (typeof obj === 'object' && obj !== null) {
                let lines = [];
                for (const key in obj) {
                    const value = obj[key];
                    let line = '';
                    if (typeof value === 'object' && value !== null) {
                        if (Array.isArray(value)) {
                            if (value.length === 0) {
                                line = `${key}: []`;
                            } else {
                                const valueYaml = jsonToYaml(value, indentLevel + 1);
                                line = `${key}:\n${valueYaml}`;
                            }
                        } else {
                            const valueYaml = jsonToYaml(value, indentLevel + 1);
                            line = `${key}:\n${valueYaml}`;
                        }
                    } else {
                        line = `${key}: ${formatValue(value)}`;
                    }
                    lines.push(`${indent}${line}`);
                }
                yaml = lines.join('\n');
                if (inArray && indentLevel > 0) {
                    // Remove leading spaces for the first line to align '-' and the first key-value pair
                    yaml = yaml.substring(indent.length);
                }
            } else {
                yaml += `${indent}${formatValue(obj)}\n`;
            }
            return yaml;
        }

        function generateDbtModels(schemaName, modelNamePrefix, tableNamePrefix) {
            const currentDatabaseRS = snowflake.execute({
                sqlText: "SELECT CURRENT_DATABASE()"
            });

            let currentDatabase = "";
            if (currentDatabaseRS.next()) {
                currentDatabase = currentDatabaseRS.getColumnValue(1);
            }

            const extraFilter = tableNamePrefix ? `AND TABLE_NAME ILIKE '${tableNamePrefix}%'` : "";
            const query = `
                        SELECT LOWER(TABLE_NAME) AS TABLE_NAME,
                               LOWER(COLUMN_NAME) AS COLUMN_NAME,
                               LOWER(DATA_TYPE) AS DATA_TYPE,
                               LOWER(TABLE_TYPE) AS TABLE_TYPE
                        FROM INFORMATION_SCHEMA.TABLES
                        JOIN INFORMATION_SCHEMA.COLUMNS
                             USING(TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME)
                        WHERE LOWER(TABLE_SCHEMA) = LOWER('${schemaName}')
                          AND LOWER(TABLE_CATALOG) = LOWER('${currentDatabase}')
                        ${extraFilter}
                        ORDER BY TABLE_NAME, ORDINAL_POSITION;
                    `;
            const rowsRs = snowflake.execute({
                sqlText: query
            });

            const modelsDict = {
                version: 2,
                models: []
            };
            let currentTable = null;
            let hasIdColumn = false;

            while (rowsRs.next()) {
                const tableName = rowsRs.TABLE_NAME;
                const columnName = rowsRs.COLUMN_NAME;
                const dataType = rowsRs.DATA_TYPE;
                const tableType = rowsRs.TABLE_TYPE;
                const modelName = modelNamePrefix ? `${modelNamePrefix}_${tableName}` : tableName;

                if (currentTable !== tableName) {
                    if (hasIdColumn) {
                        modelsDict.models[modelsDict.models.length - 1].tests = [{
                            "dbt_utils.unique_combination_of_columns": {
                                combination_of_columns: ["id"]
                            }
                        }];
                    }
                    currentTable = tableName;
                    hasIdColumn = false;
                    modelsDict.models.push({
                        name: modelName,
                        description: "",
                        columns: [],
                        type: tableType
                    });
                }

                const columnDef = {
                    name: columnName,
                    description: "",
                    data_type: dataType
                };

                if (columnName === "id") {
                    hasIdColumn = true;
                    columnDef.tests = ["dbt_constraints.primary_key"];
                    columnDef.description = "Unique record identifier";
                }
                if (columnName === "what") {
                    columnDef.tests = ["not_null"];
                    columnDef.description = "Metric measurement (see business glossary for details)";
                }

                if (columnName === "cycle") {
                    columnDef.tests = [
                        "not_null",
                        {
                            accepted_values: {
                                values: ["minute", "hour", "day", "week", "month", "year"]
                            }
                        }
                    ];
                    columnDef.description = "Reporting time period";
                }
                if (tableName.toLowerCase().startsWith("kpi_") && columnName === "value") {
                    columnDef.tests = [
                        "not_null"
                    ];
                    columnDef.description = "Metric measurement value observed at the reporting period.";
                }
                if (columnName === "cycle_timestamp") {
                    columnDef.tests = [
                        "not_null"
                    ];
                    columnDef.description = "Timestamp associated with the reporting time period start time";
                }


                if (columnName === "gl_account_number") {
                    columnDef.tests = [
                        "not_null",
                        {
                            accepted_values: {
                                values: [
                                    "1100",
                                    "2500",
                                    "6815",
                                    "1405",
                                    "4002",
                                    "4000",
                                    "6800",
                                    "4001",
                                    "6801"
                                ]
                            }
                        }
                    ];
                }

                // Dynamic handling for dimensions column:
                if (columnName === "dimensions") {
                    let dimensionTests = ["not_null"];
                    try {
                        const queryDimensionKeys = `
                                    SELECT DISTINCT R.VALUE::STRING AS KEY
                                        FROM ${currentDatabase}.${schemaName}.${tableName}
                                            JOIN LATERAL FLATTEN(input => object_keys(dimensions), OUTER => TRUE) R
                                `;
                        const dimRs = snowflake.execute({
                            sqlText: queryDimensionKeys
                        });
                        console.log("A");
                        let dimensionKeys = [];
                        while (dimRs.next()) {
                            dimensionKeys.push(dimRs.getColumnValue(1));
                        }
                        if (dimensionKeys.includes('geo')) {
                            dimensionTests.push({
                                json_key_accepted_values: {
                                    key: "geo",
                                    accepted_values: ['US', 'ROW']
                                }
                            });
                        }
                        if (dimensionKeys.includes('platform')) {
                            dimensionTests.push({
                                json_key_accepted_values: {
                                    key: "platform",
                                    accepted_values: ['iOS', 'Android', 'Web', 'Other']
                                }
                            });
                        }
                        if (dimensionKeys.includes('user_class')) {
                            dimensionTests.push({
                                json_key_accepted_values: {
                                    key: "user_class",
                                    accepted_values: ['Premium', 'Non-Premium']
                                }
                            });
                        }
                        if (dimensionKeys.includes('country')) {
                            dimensionTests.push({
                                json_key_accepted_values: {
                                    key: "country",
                                    accepted_values: ["XX"],
                                    accepted_relation: "ref('kpi__countries')",
                                    accepted_column: "alpha_2"
                                }
                            });
                        }
                    } catch (err) {
                        // In case of error, record it as a comment test
                        dimensionTests.push("-- Error retrieving dimension keys: " + err.message);
                    }
                    columnDef.tests = dimensionTests;
                    columnDef.description = "Measurement dimensional coordinates";
                }

                modelsDict.models[modelsDict.models.length - 1].columns.push(columnDef);
            }

            if (hasIdColumn) {
                modelsDict.models[modelsDict.models.length - 1].tests = [{
                    "dbt_utils.unique_combination_of_columns": {
                        combination_of_columns: ["id"]
                    }
                }];
            }

            const orderedModelsDict = reorderDict(modelsDict);
            return jsonToYaml(orderedModelsDict);
        }

        return generateDbtModels(SCHEMA_NAME, MODEL_NAME_PREFIX, TABLE_NAME_PREFIX);
    $$;
{% endset %}
  {{ run_query(sql) }}
  {{ return("") }}
{% endmacro %}