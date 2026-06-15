# Preserve original currencies and convert only for reporting

Financial facts and observations retain their original currencies, while a
Family's currency is used only as the Reporting Currency for presentation and
aggregation. Historical conversion uses dated Exchange Rate Observations and
must surface missing rates instead of silently substituting `1`; changing the
Reporting Currency never rewrites financial history.
