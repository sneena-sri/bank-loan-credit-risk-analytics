USE loan_risk_analyticsdb;


SELECT COUNT(*) AS row_count FROM borrowers;

SELECT COUNT(*) AS row_count FROM loans;

SELECT COUNT(*) AS row_count FROM loan_payments;

SELECT COUNT(*) AS row_count FROM credit_history;

SELECT COUNT(*) AS row_count FROM collateral;

SHOW WARNINGS;

SELECT *
FROM loans_raw
WHERE loan_id IN ('L200006', 'L200030', 'L200042');


