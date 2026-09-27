-- =========================================================
-- Bank Loan & Credit Risk Analytics
-- Schema: MySQL 8.0+
-- =========================================================
USE loan_risk_analyticsdb;

-- Drop tables if re-running (order matters due to FKs)
DROP TABLE IF EXISTS borrowers;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS loan_payments;
DROP TABLE IF EXISTS credit_history;
DROP TABLE IF EXISTS collateral;

-- ---------------------------------------------------------
-- borrowers
-- ---------------------------------------------------------
CREATE TABLE borrowers (
	borrower_id VARCHAR(15) PRIMARY KEY,
    application_date DATE NOT NULL,
    age INT NOT NULL,
    employment_type ENUM('Business Owner','Contract','Salaried','Self-Employed') NOT NULL,
    region ENUM('North','South','West','East'),
    annual_income INT NOT NULL,
    dependents INT,
    credit_score INT,
    existing_debt INT
);

SELECT
    r.borrower_id,
    COUNT(*) AS loan_count
FROM loans_raw r
LEFT JOIN borrowers b
    ON TRIM(r.borrower_id) = TRIM(b.borrower_id)
WHERE b.borrower_id IS NULL
GROUP BY r.borrower_id
ORDER BY r.borrower_id;

SELECT COUNT(*) AS total_borrowers
FROM borrowers;

-- ---------------------------------------------------------
-- loans
-- ---------------------------------------------------------
CREATE TABLE loans (
    loan_id VARCHAR(15) PRIMARY KEY,
    borrower_id VARCHAR(15) NOT NULL,
    application_date DATE NOT NULL,
    loan_type VARCHAR(20) NOT NULL,
    loan_amount INT NOT NULL,
    term_months INT NOT NULL,
    interest_rate DECIMAL(10,2),
    loan_status ENUM('Active','Closed','Defaulted') NOT NULL,
    default_flag BOOLEAN,
    application_channel ENUM('Online','Mobile App','Branch','Partner') NOT NULL,
    disbursement_date DATE,

    CONSTRAINT fk_loans_borrower
        FOREIGN KEY (borrower_id)
        REFERENCES borrowers(borrower_id)
);

INSERT INTO loans (
    loan_id,
    borrower_id,
    application_date,
    loan_type,
    loan_amount,
    term_months,
    interest_rate,
    loan_status,
    default_flag,
    application_channel,
    disbursement_date
)
SELECT
    TRIM(r.loan_id),
    TRIM(r.borrower_id),
    STR_TO_DATE(TRIM(r.application_date), '%Y-%m-%d %H:%i:%s'),
    TRIM(r.loan_type),
    CAST(TRIM(r.loan_amount) AS UNSIGNED),
    CAST(TRIM(r.term_months) AS UNSIGNED),
    CAST(TRIM(r.interest_rate) AS DECIMAL(10,2)),

    CASE
        WHEN LOWER(TRIM(r.loan_status)) = 'active' THEN 'Active'
        WHEN LOWER(TRIM(r.loan_status)) = 'closed' THEN 'Closed'
        WHEN LOWER(TRIM(r.loan_status)) = 'defaulted' THEN 'Defaulted'
    END,

    CAST(TRIM(r.default_flag) AS UNSIGNED),

    CASE
        WHEN LOWER(TRIM(r.application_channel)) = 'online' THEN 'Online'
        WHEN LOWER(TRIM(r.application_channel)) = 'mobile app' THEN 'Mobile App'
        WHEN LOWER(TRIM(r.application_channel)) = 'branch' THEN 'Branch'
        WHEN LOWER(TRIM(r.application_channel)) = 'partner' THEN 'Partner'
    END,

    STR_TO_DATE(TRIM(r.disbursement_date), '%Y-%m-%d %H:%i:%s')

FROM loans_raw r
WHERE EXISTS (
    SELECT 1
    FROM borrowers b
    WHERE b.borrower_id = TRIM(r.borrower_id)
);
-- ---------------------------------------------------------
-- loan_payments
-- ---------------------------------------------------------
CREATE TABLE loan_payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    loan_id VARCHAR(50) NOT NULL,
    borrower_id VARCHAR(50) NOT NULL,
    due_date DATE,
    payment_date DATE NULL,
    scheduled_principal DECIMAL(15,2),
    payment_status VARCHAR(50),
    days_past_due INT,

    CONSTRAINT fk_loanpayment_loan
        FOREIGN KEY (loan_id)
        REFERENCES loans(loan_id),

    CONSTRAINT fk_loanpayment_borrower
        FOREIGN KEY (borrower_id)
        REFERENCES borrowers(borrower_id)
);



-- ---------------------------------------------------------
-- credit_history
-- ---------------------------------------------------------
CREATE TABLE credit_history (
	borrower_id VARCHAR(15) PRIMARY KEY,
    open_accounts INT,
    delinquent_accounts INT,
    credit_history_years DECIMAL(10,2) NOT NULL,
    recent_inquiries INT,
    credit_utilization DECIMAL(10,3),
    CONSTRAINT fk_credit_borrower FOREIGN KEY(borrower_id) REFERENCES borrowers(borrower_id)
);

-- ---------------------------------------------------------
-- collateral
-- ---------------------------------------------------------
CREATE TABLE collateral (
	loan_id VARCHAR(15) PRIMARY KEY,
    collateral_type VARCHAR(15),
    collateral_value INT,
    CONSTRAINT fk_collateral_loan FOREIGN KEY(loan_id) REFERENCES loans(loan_id)
);

USE loan_risk_analyticsdb;

DROP TABLE IF EXISTS loan_payments_raw;

CREATE TABLE loan_payments_raw (
    payment_id VARCHAR(50),
    loan_id VARCHAR(50),
    borrower_id VARCHAR(50),
    due_date VARCHAR(50),
    payment_date VARCHAR(50),
    scheduled_principal VARCHAR(50),
    payment_status VARCHAR(50),
    days_past_due VARCHAR(50)
);


SELECT
    r.loan_id,
    COUNT(*) AS payment_count
FROM loan_payments_raw r
LEFT JOIN loans l
    ON r.loan_id = l.loan_id
WHERE l.loan_id IS NULL
GROUP BY r.loan_id
ORDER BY r.loan_id;

SELECT loan_id, borrower_id, loan_status, loan_amount
FROM loans
WHERE loan_id IN ('L200006', 'L200030', 'L200042');

SELECT COUNT(*) AS total_loans
FROM loans;

SELECT COUNT(*) AS total_loans
FROM loans;

USE loan_risk_analyticsdb;

DROP TABLE IF EXISTS loans_raw;

CREATE TABLE loans_raw (
    loan_id VARCHAR(50),
    borrower_id VARCHAR(50),
    application_date VARCHAR(50),
    loan_type VARCHAR(50),
    loan_amount VARCHAR(50),
    term_months VARCHAR(50),
    interest_rate VARCHAR(50),
    loan_status VARCHAR(50),
    default_flag VARCHAR(50),
    application_channel VARCHAR(50),
    disbursement_date VARCHAR(50)
);

SELECT *
FROM loans_raw
WHERE loan_id IN ('L200006', 'L200030', 'L200042');

DROP TABLE IF EXISTS loan_payments;

CREATE TABLE loan_payments (
    payment_id VARCHAR(50) PRIMARY KEY,
    loan_id VARCHAR(50) NOT NULL,
    borrower_id VARCHAR(50) NOT NULL,
    due_date DATE,
    payment_date DATE NULL,
    scheduled_principal DECIMAL(15,2),
    payment_status VARCHAR(50),
    days_past_due INT,

    CONSTRAINT fk_loanpayment_loan
        FOREIGN KEY (loan_id)
        REFERENCES loans(loan_id),

    CONSTRAINT fk_loanpayment_borrower
        FOREIGN KEY (borrower_id)
        REFERENCES borrowers(borrower_id)
);

INSERT INTO loan_payments (
    payment_id,
    loan_id,
    borrower_id,
    due_date,
    payment_date,
    scheduled_principal,
    payment_status,
    days_past_due
)
SELECT
    TRIM(r.payment_id),
    TRIM(r.loan_id),
    TRIM(r.borrower_id),

    STR_TO_DATE(
        TRIM(r.due_date),
        '%Y-%m-%d %H:%i:%s'
    ),

    CASE
        WHEN TRIM(r.payment_date) = '' THEN NULL
        ELSE STR_TO_DATE(
            TRIM(r.payment_date),
            '%Y-%m-%d %H:%i:%s'
        )
    END,

    CAST(
        NULLIF(TRIM(r.scheduled_principal), '')
        AS DECIMAL(15,2)
    ),

    NULLIF(TRIM(r.payment_status), ''),

    CAST(
        NULLIF(TRIM(r.days_past_due), '')
        AS SIGNED
    )

FROM loan_payments_raw r
INNER JOIN loans l
    ON TRIM(r.loan_id) = l.loan_id
INNER JOIN borrowers b
    ON TRIM(r.borrower_id) = b.borrower_id;
    
SELECT
    COUNT(*) AS total_payments,
    COUNT(DISTINCT payment_id) AS unique_payment_ids,
    COUNT(DISTINCT loan_id) AS unique_loans
FROM loan_payments;