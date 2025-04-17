# KPI Repository

# Quick Start

Include package and run `dbt deps`

```yaml
# In consuming packages.yml
packages:
  - git: "https://github.com/your-org/kpi_repository.git"
    revision: "main"  # or a specific tag like "0.1.0"

```

Design your custom KPI models to interface and include them in `kpi_repository_models`

```yaml
# In consuming dbt_project.yml
vars:
  kpi_repository_models:
    - my_custom_acquisition_model
    - my_custom_conversion_model
    - my_custom_engagement_model
    - my_custom_retention_model
```

Provide your own seed files

- operating plan targets
- business glossary
- country holidays
- shadow overrides

## Overview
The repository is designed to consolidate diverse key performance indicators (KPIs) 
from multiple domains into a single source of truth. The models are built with incremental 
processing logic to ensure that only fully completed reporting periods are processed. This
guarantees that partial or future data do not skew the results. By maintaining a rigorous 
data dictionary and business glossary, every metric has a well-defined business meaning and
standardized methodology. 

This not only minimizes miscommunication between business and technical stakeholders but also 
reinforces accountability across the board. Moreover, a disciplined review cadence—whether weekly, 
monthly, or quarterly—enables consistent state-of-the-business assessments to inform strategic 
decisions and operational adjustments.

At the foundation of the repository lies the central model that aggregates data from numerous 
component modules (such as registrations, active users, and trial starts) into a unified KPI 
repository. This design ensures consistency and allows for efficient cross-domain analysis. 
For example, the performance report model seamlessly merges current and prior measurements, 
enriching the raw data with historical context and optional AOP (Annual Operating Plan) targets 
to highlight year-over-year trends. Business leaders thus benefit from real-time insights that 
are both granular and strategic, supporting better forecasting and proactive response to market 
dynamics.

## Organization

This repository forms an integrated ecosystem of dbt models meticulously designed to measure, analyze, 
and report on key aspects of the business, from acquisition through conversion, engagement, and retention. 
By relying on consistent incremental processing, refined dimensional mapping, and rigorous aggregation strategies, 
the repository delivers trustworthy and actionable insights to both tactical and strategic decision-makers. 
The detailed business glossary and data dictionary further standardize terminology and methodologies, 
ensuring clarity and fostering cross-functional collaboration. This unified framework enables precise 
monitoring of business performance, supports proactive strategy adjustments during regular cadence reviews,
and ultimately drives sustainable growth and profitability.

### Acquisition

In the acquisition domain, a suite of models tracks the entire user funnel from initial registration 
to ongoing engagement. The Active Registered Users module calculates the count of unique users engaging 
within a reporting period by aggregating session logs and normalizing user data against standardized 
dimensions like geography, platform, and subscription tier. Complementing this, the Registrations model
records new sign-ups by processing user metadata, ensuring accurate roll-ups by mapping country codes 
and platform identifiers consistently. The Resurrected Users model focuses on reactivation by identifying
users who return after prolonged inactivity, illuminating the effectiveness of re-engagement strategies. 
External market performance is captured by the Store Rank module, which benchmarks the app’s position in 
app store charts using Sensor Tower data, and the Trial Starts module counts the initiation of trial 
subscriptions with differentiation between new and existing users. Finally, the New Users model 
synthesizes registration and resurrection data to reflect the net growth of the active user base. 
Together, these acquisition metrics provide a detailed picture of growth drivers, identify the most 
effective channels, and guide strategic initiatives on user activation.

### Conversion
Conversion metrics in the repository extend the analysis from user acquisition to the monetization journey.
The Registration-to-Trial Conversion model (measuring RTT_F1D_CVR, RTT_F30D_CVR, and associated counts) 
examines how effectively newly registered cohorts initiate trials within specific time windows, after 
shifting the reporting period appropriately to allow ample time for conversion to occur. Building on this, 
the Trial-to-Premium Conversion model evaluates how many trial users transition to premium subscriptions, 
thereby quantifying the effectiveness of the trial model as a conversion tool. In addition, the Trial vs 
Direct model distinguishes premium subscribers based on whether they entered through a trial conversion 
path or switched directly, providing a nuanced view of revenue generation sources and informing both 
product and marketing strategies. These conversion models optimize the funnel efficiency and underpin 
decisions regarding promotional efforts and customer engagement policies.

### Engagement
Engagement metrics capture the depth and quality of user interactions with the core app functions. The 
Active Food Users model counts users who log food entries during the reporting period, segmented by 
geography, platform, and subscription class. This model aggregates logs from detailed event data to 
highlight active participation in one of the app’s key features. The Average Daily Active Registered Users
(DARU) metric provides a smoothed view by averaging daily active counts over the period, allowing for 
trend detection and effective target-setting. The Consecutive Food Users model further refines this insight
by identifying users with continuous engagement across back-to-back periods, thus measuring habitual
behavior and user retention beyond a single cycle. Early-stage engagement is particularly critical;
the Initial Food Users series is split into two parts where Part 1 captures raw counts of users who log 
food within 24 hours and 7 days post-registration (along with the average food logs for the first week), 
and Part 2 calculates the percentage of new registrants who show early food logging behavior by joining 
with registration metrics , . Collectively, these engagement models provide actionable insights into user
behavior and assist in refining feature implementations and engagement strategies.

### Retention
Retention metrics offer a long-term view by tracking how well premium subscriptions are maintained over time,
making them fundamental to sustaining recurring revenue. The End-of-Period Premium Subscribers model 
calculates the number of non-trial premium subscriptions that remain active at the close of each reporting 
period. By generating a detailed calendar spine and joining against the premium transactions data, the model 
ensures that only subscriptions still in force at the end of the period are counted, and further segmented by 
geography, platform, subscription frequency, and user tier. The Premium Subscription Renewal Rate model, which 
measures PN_OVER_PN_MINUS_1_RATE, examines the renewal behavior by comparing consecutive pay numbers, thus 
offering a direct view of customer retention in recurring billing cycles. Furthermore, the Subscription Renewals
model computes the overall renewal rate by determining the number of subscriptions up for renewal versus those
successfully renewed within the period. These models work in tandem to provide a comprehensive picture of 
retention performance, revealing not only the overall health of the subscription base but also the effectiveness
of renewal strategies across various customer segments.




## Execution Flow

The entire processing workflow is designed as a layered, sequential pipeline that starts at the granular module
level and builds up to holistic performance and trend analyses. In the first stage, individual modules dedicated 
to specific domains—acquisition, conversion, engagement, and retention—are executed and rigorously tested. These
modules operate incrementally, ingesting raw source data, applying their tailored filtering, transformations, and
aggregations, and then outputting standardized metrics at the lowest level of granularity.

Once each module’s data is validated and the individual KPIs are produced, the next stage merges these discrete
outputs into the unified KPI repository. This repository serves as the single source of truth, consolidating 
multiple dimensions (such as geography, platform, subscription tier, and user class) across domains into consistent,
comparable tables. The repository itself undergoes its own series of tests to ensure that the union of all modules
adheres to the strict data quality and dimensional standards defined in the business glossary.

With the repository in place, the performance report model is executed. This model integrates both current and 
historical measurements from the KPI repository, enriching the data with trends and optional Annual Operating 
Plan (AOP) targets. The performance report model is specifically designed to enable period-over-period comparisons, 
aligning raw metrics with strategic objectives and thus providing a clear snapshot of the company’s performance 
over time.

Finally, the timeseries analysis model takes the consolidated KPIs and performs anomaly detection by analyzing 
the historical evolution of these metrics. This last stage is critical to flag any deviations or outliers that may
require immediate attention, ensuring that stakeholders can quickly respond to emerging trends or issues.

Overall, the sequence is as follows:

**Module Execution and Testing**: 

All individual domain-specific modules (acquisition, conversion, engagement, and retention) are 
processed and validated.

**KPI Repository Construction**: 

Outputs from the modules are aggregated to build a single, comprehensive repository that standardizes 
and unifies the metrics.

**Performance Reporting**: 

The repository feeds into the performance model, which combines current and prior period data (and AOP 
targets when applicable) for insightful period-over-period analysis.


**Time Series Analysis**: 

Historical KPI data from the repository is then processed to detect anomalies and trends, enabling proactive 
monitoring.

## Model Lineage

[insert image here]

## Data Structures

Below is a comprehensive outline of the field‐level structure for each module and the consolidated KPI repository. 
In our architecture, each module is a self‐contained unit that outputs a standardized set of fields to ensure 
consistency and interoperability. All modules share a common set of core fields (such as indicator, dimensions, 
cycle, cycle_timestamp, value, and id) that allow them to be unioned into the central KPI repository. The fields 
are defined in our dbt YAML configurations and are validated via tests and accepted value constraints in the business
glossary.

### Core Fields Common Across Modules and Repository

**INDICATOR (STRING)**

A standardized, human‐readable metric name (for example “ACTIVE_REGISTERED_USERS”, “TRIAL_STARTS”, etc.). Each module restricts accepted values based on its domain logic.


**DIMENSIONS (OBJECT)**

A JSON object holding the key–value pairs that represent the metric’s dimensional breakdown. Typical keys include:

* geo (usually ‘US’ or ‘ROW’)
* country (a standardized ISO alpha‐2 code or fallback “XX”)
* platform (e.g., ‘iOS’, ‘Android’, ‘Web’, or ‘Other’)
* Additional fields such as user_class, subscription_frequency, conversion_path, paynumber, or user_tenure_class, depending on the module.

**CYCLE (STRING)**

Indicates the reporting period type (e.g., day, week, bi-week, month, quarter, or year).

**CYCLE_TIMESTAMP (TIMESTAMP_NTZ)**

The start time of the reporting period. This field is often derived by truncating a date (or a date plus an offset) 
according to the reporting period granularity.

**VALUE (NUMBER)**

The primary numeric measure of the metric. For instance, the count of users, the average rank, or a computed 
conversion ratio.

**ID (STRING)**


A unique record identifier generated via a surrogate key function (using the combination of indicator, dimensions, cycle, and cycle_timestamp).

**_DBT_SOURCE_RELATION (STRING)** 

Note: *present only in the repository*

Indicates the originating model of the data, allowing for traceability and validation of source origins.



## KPI Repository Structure ##

The KPI repository aggregates the outputs from all the individual modules into a single, unified table. 
Its fields are designed to preserve the information needed for downstream performance reporting and 
timeseries analysis. 

   

**KPI__AOP_TARGETS**

This table stores the Annual Operating Plan (AOP) targets broken down into granular KPI targets. These targets are used in performance reports to compare planned versus actual performance.

Key Fields:
- CYCLE_TIMESTAMP: A timestamp (without time zone) that marks the start of the reporting period.
- PLAN: A numeric value (precision 18, scale 8) representing the targeted KPI value for that cycle.
- INDICATOR: A string that identifies the specific KPI (e.g., “TRIAL_STARTS”, “REGISTRATIONS”).
- DIMENSIONS: A string containing a JSON representation of the dimensional context (for example, geo, platform, etc.).
- CYCLE: A string indicating the reporting period type (e.g., “day”, “week”).
   
**KPI__COUNTRIES**

This table standardizes country codes and related attributes to ensure consistent geography-related dimensions across all models.

Key Fields:
- ALPHA_2: A 2-character string representing the ISO 3166-1 alpha-2 country code.
- ALPHA_3: A 3-character string representing the ISO 3166-1 alpha-3 country code.
- FLAG: A string field intended to hold an emoji or similar representation of the national flag.
- NAME: The full country name as a string.

**KPI__COUNTRY_HOLIDAYS_FOOD_OVERLOAD**

This seed captures specific holidays associated with food overloading, which can be used for seasonal analysis
or to adjust KPIs in periods known for unusual activity.

Key Fields:
- COUNTRY: A string indicating the country (typically matching the ISO alpha-2 code).
- DATE: A date field indicating when the holiday occurs.
- HOLIDAY: A string containing the name of the holiday.

**KPI__COUNTRY_REGIONS**

This dataset provides a mapping between country codes and their broader regions. It supports additional geographic segmentation in reporting.

Key Fields:
- COUNTRY_CODE: A 2-character string, usually following the ISO alpha-2 standard.
- REGION: A string that specifies the broader region (for example, “Europe”, “Asia”).

**KPI__REPOSITORY_SHADOW**

The repository shadow serves as an override mechanism that allows designated operators to adjust or replace 
incorrect KPI values generated from the raw data. These overrides can be uploaded via a seed file so that the
KPI repository uses the corrected values. This process is controlled under stringent IT and compliance (e.g., SOX)
frameworks.

Key Fields:
- INDICATOR: A string defining the affected KPI name.
- DIMENSIONS: A string capturing the dimensional context in JSON format.
- CYCLE_TIMESTAMP: A timestamp (without time zone) indicating the reporting period start.
- CYCLE: A string representing the reporting period type.
- VALUE: A numeric field (precision 18, scale 8) that holds the overridden KPI value.
- ID: A unique identifier (string) for the overridden record.
  
**KPI__SOCIETAL_GENERATIONS**

This seed provides additional demographic segmentation by defining societal generations. It can be used to 
analyze trends or adoption rates by generational cohorts.

Key Fields:
- GENERATION: A string that names the generation (for example, “Millennials”, “Generation X”).
- FROM_YEAR: A numeric value (4-digit) representing the starting year for the generation.
- UPTO_YEAR: A numeric value (4-digit) representing the ending year for the generation.

## Data Testing
_Integrity, completeness, consistency, and dimension validation_

The testing regime in the KPI repository concentrates on ensuring data completeness, accuracy, consistency, 
and timeliness. These themes collectively support a trustworthy data pipeline that underpins effective business 
intelligence and strategic decision-making.

The repository enforces robust quality controls through a series of tests that focus on several core themes:

- **Data Integrity and Uniqueness**:

    Fields that are critical for analysis—such as unique identifiers, cycle timestamps, and core metric 
    names—must never be null. Tests ensure that both individual key fields and combinations (for instance, 
    the surrogate key created from indicator, dimensions, cycle, and cycle_timestamp) are unique, preventing 
    duplication across records.

- **Dimensional Consistency and Standardization**:

    Given that many models rely on a JSON object for dimensions, tests verify that every key (for example, geo, 
    platform, country, and subscription-related fields) strictly adheres to a pre-defined set of accepted values. 
    This preserves consistency and ensures that every dimension aligns with the business glossary and standard 
    data dictionary definitions.

- **Cross-Model Consistency**:

    Some tests cross-reference values from one model to another. For example, assertions ensure that each KPI 
    indicator used in a module is also defined in the centralized business glossary. This establishes a common 
    language across all models and guarantees that every metric is accurately described.

- **Data Freshness and Incremental Logic**:

    Specialized “freshness” tests ensure that data is timely; they check that only fully closed reporting periods 
    are processed unless the backfill mode is explicitly enabled. This prevents the inclusion of incomplete or 
    future data and supports reliable trend analysis.



## KPI repository in derivative works

The KPI repository is not merely a static data warehouse; it is a dynamic foundation that fuels a broad spectrum of derivative works and analytical efforts across the organization. At its core, the repository standardizes key performance indicators—spanning acquisition, conversion, engagement, and retention—into a consistent and reliable source of truth. This single source empowers downstream applications such as Tableau dashboards, advanced statistical analyses, predictive modeling, forecasting, and board-level reporting.
One of the primary derivative uses of the repository data is in the construction of interactive Tableau dashboards and reports. Because the repository enforces dimensional consistency and standardized metrics, Tableau users can build intuitive visualizations that allow decision-makers to drill down into metrics by geography, platform, subscription tiers, and more. Dashboards derived from this repository offer a live, interactive snapshot of business performance, enabling users to explore trends, compare historical performance, and perform real-time filtering with confidence that the underlying data is both complete and accurate.
Beyond visual reporting, the repository serves as a critical input for more sophisticated statistical analyses, such as principal component analysis (PCA). By leveraging the rich, multidimensional nature of the repository data, analysts can apply PCA to distill the complex interrelationships among various KPIs into a smaller set of underlying factors. This dimensionality reduction not only simplifies the analytics landscape, but it also highlights the key drivers that contribute most to variability in performance, focusing strategic attention on the factors that matter most.
Descriptive and predictive analytics also find a strong foothold in the repository’s well-organized data. Descriptive analytics uses aggregated measures to paint a detailed picture of historical performance—for example, by summarizing trends over time or comparing performance across different customer segments. In contrast, predictive analytics takes advantage of the repository’s historical granularity and consistency to train forecasting models. Predictive models can estimate future trends such as customer churn, conversion rates, or revenue from premium subscriptions. When these forecasts are combined with advanced time series decomposition, they reveal patterns of trend and seasonality, which are essential for operational planning and resource allocation.
Forecasting efforts derive significant benefit from the repository’s timestamped metrics. The models that track performance indicators over distinct reporting periods allow forecasters to identify seasonal effects, cycles, and long-term trends. For instance, by analyzing historical patterns in user engagement or retention rates, forecasting models can predict future performance with greater precision. This capability is critical for aligning business expectations with the Annual Operating Plan and adjusting strategies on a weekly, monthly, or quarterly basis as needed.
At the most strategic level, the repository underpins the Board of Directors' reporting. The consolidated data, enriched through incremental updates and rigorous testing, ensures that board decks reflect an accurate and timely view of business performance. Automated tools such as the board deck generator draw directly from the repository to create polished presentations that combine charts, narrative context, and benchmarking information. These presentations distill complex data into actionable insights, enabling boards to focus on strategic initiatives rather than data collection.
The KPI repository’s derivative uses span a wide range of activities—from interactive visualizations and advanced statistical analyses to predictive modeling, forecasting, and high-level board reporting. Each derivative work leverages the repository’s standardized metrics and dimensions to ensure that all insights are consistent, reliable, and aligned with the strategic objectives of the organization. This integrated approach not only enhances internal decision-making but also reinforces the organization’s ability to adapt quickly in a dynamic marketplace.

- **Board Deck Automation for Executive Reporting**

    The board deck generator automates the creation and update of board-level presentations by leveraging the 
    unified KPI repository data. It performs several key functions:

  - Authenticates and connects with Google Sheets, Slides, and Drive APIs to retrieve and update content.
  - Creates or refreshes target spreadsheets in shared Google Drive folders to host up-to-date data and chart representations. 
  - Processes raw data into well-formatted, pivoted DataFrames—arranging weekly KPI values, alongside computed year-over-year deltas—in an easily consumable tabular form. 
  - Generates and embeds charts into Google Slides with a consistent, professional layout (e.g., adding drop shadows, color palettes, and using pre-defined positions). 
  - Deletes outdated slides and inserts new slides between established boundary slides, ensuring that the presentation is always current.
  
  This end-to-end automation enables business intelligence teams to quickly generate board decks that accurately reflect the latest performance trends without manual intervention.

-  **Dynamic Spreadsheet Updates for Interactive Dashboards**
   
    Another potential use is the sheet update module. It is the automated synchronization between the KPI 
    repository and external spreadsheet tools. 

    This use case includes:

   - Pulling processed KPI data from the repository and writing it into designated worksheets for ongoing analysis.
   - Automatically refreshing dashboard reports in Google Sheets so that non-technical stakeholders can interact with the current metrics without delving into raw SQL or dbt code.
   - Coordinating with other downstream tools (like the board deck generator) to ensure that the source data for visualizations is always up-to-date.

- **Segmentation of Monthly AOP Targets**

    Every quarter, FP refreshes forecasts, and BI needs to split monthly forecasts into daily, weekly, and bi-weekly 
    levels of granularity. A dedicated module provides a specialized functionality to break down Annual Operating Plan
    (AOP) targets into more granular sub-monthly increments.

    Its key uses include:

   - Transforming high-level, annual targets into operational benchmarks that are aligned with the KPI reporting cadence.
   - Facilitating closer monitoring of performance against set goals by providing a clear monthly view, which can be integrated into weekly or board-level reports.
   - Enabling a more responsive strategy in addressing any deviations between plan and actual performance, as changes can be tracked and communicated more frequently.

- **Weekly Commentary and Contextual Reporting**

    A module dedicated to weekly commentary transforms quantitative KPI outcomes into narrative summaries. 

    Its benefits include:

    - Highlighting key trends, anomalies, or events affecting business performance, distilled into plain language for a broader audience.
    - Guiding analysts in drafting executive summaries with pre-aggregated and context-rich insights derived from the data warehouse.
    - Ensuring that board reports and internal communications are not only data-rich but also offer the necessary narrative context to drive decision-making.

- **Integrated Workflow and End-to-End Automation**
    Use of Python in conjunction with dbt models allows building a comprehensive automation pipeline that connects the KPI repository to multiple downstream applications:
   - The KPI repository supplies a single source of truth for all performance metrics.
   - Automated processes then ingest this repository output into spreadsheets and slides, using modules like sheet_update and board_deck_generator to transform raw data into actionable insights.
   - The split monthly AOP targets module makes sure that planned targets are dynamically aligned with measured performance, while weekly commentary provides analytical context.

This integrated approach minimizes manual intervention, reduces errors, and creates a streamlined feedback loop that improves both operational efficiency and strategic decision-making. 


