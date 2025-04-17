{% macro create_create_remove_outliers_and_average_udf(model_relation) %}
{#
  Expects:
    - model_relation: A dbt relation object (e.g. {{ this }})
      used to extract the target database and schema.
#}
{% set database = model_relation.database %}
{% set schema = model_relation.schema %}
{% set sql %}
CREATE OR REPLACE FUNCTION {{ database }}.{{ schema }}.REMOVE_OUTLIERS_AND_AVERAGE(ARR ARRAY)
        returns FLOAT
        language JAVASCRIPT
    as
    $$
           function removeOutliersAndComputeAverage(arr) {
                if (arr.length !== 6) {
                    throw new Error("The array must always contain exactly 6 elements.");
                }

                // Helper function to calculate the mean
                const calculateMean = (numbers) => {
                    return numbers.reduce((a, b) => a + b, 0) / numbers.length;
                };

                // Helper function to calculate population standard deviation
                const calculateStdDev = (numbers, mean) => {
                    const variance = numbers.reduce((acc, num) => acc + Math.pow(num - mean, 2), 0) / numbers.length;
                    return Math.sqrt(variance);
                };

                let iterations = 0;

                while (iterations < 3) {
                    const mean = calculateMean(arr);
                    const stdDev = calculateStdDev(arr, mean);
                    const lowerBound = mean - 2 * stdDev;
                    const upperBound = mean + 2 * stdDev;

                    // Find the largest outlier (farthest from the mean) outside the bounds
                    let largestOutlierIndex = -1;
                    let maxDistance = 0;

                    arr.forEach((num, index) => {
                        if (num < lowerBound || num > upperBound) {
                            const distance = Math.abs(num - mean);
                            if (distance > maxDistance) {
                                maxDistance = distance;
                                largestOutlierIndex = index;
                            }
                        }
                    });

                    // If no outliers are found, break out of the loop
                    if (largestOutlierIndex === -1) {
                        break;
                    }

                    // Remove the largest outlier
                    arr.splice(largestOutlierIndex, 1);
                    iterations++;

                    // Stop if fewer than two elements remain (to avoid meaningless averages)
                    if (arr.length < 2) {
                        break;
                    }
                }

                // Return the average of the remaining elements
                return calculateMean(arr);
            }

            // Parse Snowflake ARRAY and process
            return removeOutliersAndComputeAverage(ARR);
    $$;
{% endset %}
{{ run_query(sql) }}
{{ return("") }}
{% endmacro %}
