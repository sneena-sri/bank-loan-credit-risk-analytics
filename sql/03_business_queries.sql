USE loan_risk_analyticsdb;

# 1. Return total loans, total original loan amount, average loan amount, active/closed/defaulted counts and loan-level default rate. Use cleaned loan records only.
SELECT
	COUNT(*) AS total_loans,
    SUM(loan_amount) AS total_loan_amount,
    AVG(loan_amount) AS avg_loan_amount,
    SUM(CASE WHEN loan_status = 'Active' THEN 1 ELSE 0 END) AS active_loans,
    SUM(CASE WHEN loan_status = 'Closed' THEN 1 ELSE 0 END) AS closed_loans,
    SUM(CASE WHEN loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
    ROUND(100 * SUM(CASE WHEN default_flag=1 THEN 1 ELSE 0 END) / COUNT(*),2) AS defaulte_rate_percent
FROM loans;

# 2. Calculate monthly loan count and total disbursed amount using disbursement_date. Include month-over-month change in amount.
WITH monthly AS (
	SELECT
		DATE_FORMAT(disbursement_date, '%Y-%m') AS loan_month,
        COUNT(*) AS loan_count,
        SUM(loan_amount) AS total_amount
	FROM loans
    WHERE disbursement_date IS NOT NULL
    GROUP BY DATE_FORMAT(disbursement_date, '%Y-%m')
)

SELECT
	loan_month,
    loan_count,
    total_amount,
    total_amount - LAG(total_amount) OVER (ORDER BY loan_month) AS mom_change_amount
FROM monthly
ORDER BY loan_month;

# 3. For each loan type, show loan count, total exposure, default count and default rate.
SELECT
	loan_type,
    COUNT(*) AS loan_count,
    SUM(loan_amount) AS total_exposure,
    SUM(default_flag) AS default_count,
    ROUND(100 * SUM(default_flag) / COUNT(*),2) AS default_rate_percent
FROM loans
GROUP BY loan_type
ORDER BY default_rate_percent DESC;

# 4. Join Borrowers to Loans, create score bands and compare loan count, exposure and default rate.
SELECT
	CASE
		WHEN b.credit_score<580 THEN 'Poor'
        WHEN b.credit_score BETWEEN 580 AND 669 THEN 'Fair'
        WHEN b.credit_score BETWEEN 670 AND 739 THEN 'Good'
        WHEN b.credit_score BETWEEN 740 AND 799 THEN 'Very Good'
        WHEN b.credit_score>=800 THEN 'Excellent'
        ELSE 'Unknown'
	END AS credit_score_band,
    COUNT(*) AS loan_count,
    SUM(l.loan_amount) AS total_exposure,
    SUM(l.default_flag) AS default_count,
    ROUND(100 * SUM(l.default_flag)/COUNT(*),2) AS default_rate_percent
FROM borrowers b
JOIN loans l ON b.borrower_id = l.borrower_id
GROUP BY CASE
		WHEN b.credit_score<580 THEN 'Poor'
        WHEN b.credit_score BETWEEN 580 AND 669 THEN 'Fair'
        WHEN b.credit_score BETWEEN 670 AND 739 THEN 'Good'
        WHEN b.credit_score BETWEEN 740 AND 799 THEN 'Very Good'
        WHEN b.credit_score>=800 THEN 'Excellent'
        ELSE 'Unknown'
        END
ORDER BY credit_score_band;

# 5. Find segments with above-average loan exposure and above-average default rate. Define clearly whether exposure means average loan amount or total amount.
WITH segment_metrices AS (
	SELECT
		loan_type,
        COUNT(*) AS loan_count,
        AVG(loan_amount) AS avg_loan_amount,
        SUM(default_flag) AS default_count,
        ROUND(100 * SUM(default_flag)/COUNT(*),2) AS default_rate_percent
	FROM loans
    GROUP BY loan_type
),
overall_metrices AS (
	SELECT
		AVG(loan_amount) AS overall_avg_loan_amount,
        ROUND(100 * SUM(default_flag)/COUNT(*),2) AS overall_default_rate_percent
	FROM loans
)

SELECT
	s.loan_type,
    s.loan_count,
    ROUND(s.avg_loan_amount,2) AS avg_loan_amount,
    s.default_count,
    s.default_rate_percent,
    ROUND(o.overall_avg_loan_amount,2) AS overall_avg_loan_amount,
    o.overall_default_rate_percent
FROM segment_metrices s
CROSS JOIN overall_metrices o
WHERE s.avg_loan_amount > o.overall_avg_loan_amount
AND s.default_rate_percent > o.overall_default_rate_percent
ORDER BY s.default_rate_percent DESC;

# 6. Identify borrowers with the highest total original loan exposure. Show number of loans, total exposure and defaulted loans.
SELECT
	borrower_id,
    COUNT(*) AS loan_count,
    SUM(loan_amount) AS total_exposure,
    SUM(CASE WHEN loan_status='Defaulted' THEN 1 ELSE 0 END) AS defaulted_loans
FROM loans
GROUP BY borrower_id
ORDER BY total_exposure DESC;

# 7. For each borrower with payment records, calculate number of scheduled payments, on-time payments, late/missed payments and average days past due.
SELECT
	borrower_id,
    COUNT(*) AS scheduled_payment,
    SUM(CASE WHEN payment_status='On Time' THEN 1 ELSE 0 END) AS ontime_payments,
    SUM(CASE WHEN payment_status IN ('Late','Missed') THEN 1 ELSE 0 END) AS late_missed_payments,
    ROUND(AVG(days_past_due),2) AS avg_days_past_due
FROM loan_payments
GROUP BY borrower_id
ORDER BY avg_days_past_due DESC;

# 8. Calculate late/missed payment rate and average days past due by loan type.
SELECT
	l.loan_type,
    SUM(CASE WHEN lp.payment_status IN ('Late','Missed') THEN 1 ELSE 0 END) AS late_missed_payments,
    ROUND(100 * SUM(CASE WHEN lp.payment_status IN ('Late','Missed') THEN 1 ELSE 0 END) / COUNT(*),2) AS late_missed_rate_percent,
    ROUND(AVG(lp.days_past_due),2) AS avg_past_due
FROM loans l
JOIN loan_payments lp ON l.loan_id = lp.loan_id
GROUP BY l.loan_type
ORDER BY late_missed_rate_percent DESC;

# 9. Calculate defaulted loan exposure as a percentage of total loan exposure.
SELECT
	SUM(CASE WHEN loan_status='Defaulted' THEN loan_amount ELSE 0 END) AS defaulted_loan,
    SUM(loan_amount) AS total_exposure,
    ROUND(100 * SUM(CASE WHEN loan_status='Defaulted' THEN loan_amount ELSE 0 END) / SUM(loan_amount),2) AS defaulted_exposure_percent
FROM loans
ORDER BY defaulted_exposure_percent DESC;

# 10. Group loans by disbursement month and calculate default count and default rate for each cohort.
SELECT
    DATE_FORMAT(disbursement_date, '%Y-%m') AS disbursement_month,
    COUNT(*) AS total_loans,
    SUM(default_flag) AS default_count,
    ROUND(
        100.0 * SUM(default_flag) / COUNT(*),
        2
    ) AS default_rate_percent
FROM loans
WHERE disbursement_date IS NOT NULL
GROUP BY DATE_FORMAT(disbursement_date, '%Y-%m')
ORDER BY disbursement_month;

# 11. For every loan, identify its latest payment record and return the latest payment status and days past due.
WITH latest_payment AS (
SELECT
	loan_id,
    payment_status,
    days_past_due,
    payment_date,
    ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY payment_date DESC) AS rnk
FROM loan_payments
WHERE payment_date IS NOT NULL
)

SELECT
	loan_id,
    payment_date AS latest_payment_date,
    payment_status AS latest_payment_status,
    days_past_due AS latest_days_past_due
FROM latest_payment
WHERE rnk = 1
ORDER BY loan_id;

# 12. Combine credit score, utilization, income, existing debt and loan exposure. Flag borrowers meeting at least two project-defined risk conditions.
WITH borrower_exposure AS (
    SELECT
        borrower_id,
        SUM(loan_amount) AS total_loan_exposure
    FROM loans
    GROUP BY borrower_id
),

overall_exposure AS (
    SELECT
        AVG(total_loan_exposure) AS avg_borrower_exposure
    FROM borrower_exposure
),

risk_assessment AS (
    SELECT
        b.borrower_id,
        b.credit_score,
        ch.credit_utilization,
        b.annual_income,
        b.existing_debt,
        COALESCE(be.total_loan_exposure, 0) AS total_loan_exposure,

        CASE
            WHEN b.credit_score < 660 THEN 1
            ELSE 0
        END AS low_credit_score,

        CASE
            WHEN ch.credit_utilization > 0.70 THEN 1
            ELSE 0
        END AS high_utilization,

        CASE
            WHEN b.annual_income > 0
             AND b.existing_debt / b.annual_income > 0.50
            THEN 1
            ELSE 0
        END AS high_debt_to_income,

        CASE
            WHEN COALESCE(be.total_loan_exposure, 0)
                 > oe.avg_borrower_exposure
            THEN 1
            ELSE 0
        END AS high_loan_exposure

    FROM borrowers b

    LEFT JOIN credit_history ch
        ON b.borrower_id = ch.borrower_id

    LEFT JOIN borrower_exposure be
        ON b.borrower_id = be.borrower_id

    CROSS JOIN overall_exposure oe
)

SELECT
    borrower_id,
    credit_score,
    credit_utilization,
    annual_income,
    existing_debt,
    total_loan_exposure,

    low_credit_score,
    high_utilization,
    high_debt_to_income,
    high_loan_exposure,

    (
        low_credit_score
        + high_utilization
        + high_debt_to_income
        + high_loan_exposure
    ) AS risk_condition_count,

    CASE
        WHEN (
            low_credit_score
            + high_utilization
            + high_debt_to_income
            + high_loan_exposure
        ) >= 2
        THEN 'High Risk'
        ELSE 'Lower Risk'
    END AS risk_flag

FROM risk_assessment

WHERE (
    low_credit_score
    + high_utilization
    + high_debt_to_income
    + high_loan_exposure
) >= 2

ORDER BY
    risk_condition_count DESC,
    total_loan_exposure DESC;
    
# 13. Rank loans within each loan type by loan amount and separately by credit risk indicator/default status.
SELECT
    loan_id,
    loan_type,
    loan_amount,
    default_flag,

    RANK() OVER (
        PARTITION BY loan_type
        ORDER BY loan_amount DESC
    ) AS loan_amount_rank,

    RANK() OVER (
        PARTITION BY loan_type
        ORDER BY default_flag DESC, loan_amount DESC
    ) AS credit_risk_rank

FROM loans

ORDER BY
    loan_type,
    credit_risk_rank;
    
# 14. Find borrowers with more than one loan. Compare their average loan amount, total exposure and default rate with single-loan borrowers.
WITH borrower_summary AS (
	SELECT
		borrower_id,
        COUNT(*) AS loan_count,
        SUM(loan_amount) AS total_exposure,
        AVG(loan_amount) AS avg_loan_amt,
        SUM(default_flag) AS defaulted_loans,
        100.0 * SUM(default_flag) / COUNT(*) AS default_rate
	FROM loans
    GROUP BY borrower_id
),
borrower_groups AS (
    SELECT
        borrower_id,
        loan_count,
        avg_loan_amt,
        total_exposure,
        defaulted_loans,
        default_rate,

        CASE
            WHEN loan_count > 1 THEN 'Multiple Loans'
            ELSE 'Single Loan'
        END AS borrower_group
    FROM borrower_summary
)

SELECT
    borrower_group,
    COUNT(*) AS borrower_count,
    ROUND(AVG(avg_loan_amt), 2) AS avg_loan_amt,
    ROUND(SUM(total_exposure), 2) AS total_exposure,
    SUM(defaulted_loans) AS defaulted_loans,
    ROUND(
        100.0 * SUM(defaulted_loans) / SUM(loan_count),
        2
    ) AS default_rate_percent
FROM borrower_groups
GROUP BY borrower_group
ORDER BY borrower_group;

# 15. Identify borrowers or loans with repeated missed/delinquent payments. Define a streak as consecutive payment records with non-on-time status.
WITH payment_sequence AS (
    SELECT
        payment_id,
        loan_id,
        borrower_id,
        due_date,
        payment_status,

        CASE
            WHEN payment_status <> 'On Time' THEN 1
            ELSE 0
        END AS non_on_time,

        ROW_NUMBER() OVER (
            PARTITION BY loan_id
            ORDER BY due_date, payment_id
        ) AS payment_sequence

    FROM loan_payments
),

streak_flags AS (
    SELECT
        *,
        CASE
            WHEN non_on_time = 1
             AND (
                    LAG(non_on_time) OVER (
                        PARTITION BY loan_id
                        ORDER BY payment_sequence
                    ) = 0
                    OR
                    LAG(non_on_time) OVER (
                        PARTITION BY loan_id
                        ORDER BY payment_sequence
                    ) IS NULL
                 )
            THEN 1
            ELSE 0
        END AS new_streak

    FROM payment_sequence
),

streak_groups AS (
    SELECT
        *,
        SUM(new_streak) OVER (
            PARTITION BY loan_id
            ORDER BY payment_sequence
        ) AS streak_id

    FROM streak_flags
),

streaks AS (
    SELECT
        loan_id,
        borrower_id,
        streak_id,
        COUNT(*) AS streak_length,
        MIN(due_date) AS streak_start_date,
        MAX(due_date) AS streak_end_date

    FROM streak_groups

    WHERE non_on_time = 1

    GROUP BY
        loan_id,
        borrower_id,
        streak_id
)

SELECT
    loan_id,
    borrower_id,
    streak_length,
    streak_start_date,
    streak_end_date

FROM streaks

WHERE streak_length >= 2

ORDER BY
    streak_length DESC,
    loan_id;
    
# 16. Compare application channels by loan count, average loan amount, total exposure, default rate and average interest rate.
SELECT
	application_channel,
    COUNT(*) AS channel_count,
    ROUND(AVG(loan_amount),2) AS avg_loan_amount,
    SUM(loan_amount) AS total_exposure,
    SUM(default_flag) AS default_count,
    ROUND(100* SUM(default_flag) / COUNT(*),2) AS default_rate_pct,
    ROUND(AVG(interest_rate),2) AS avg_interest_amount
FROM loans
GROUP BY application_channel
ORDER BY application_channel;

# 17. For each region, show borrowers, loans, exposure, average credit score and default rate. Add a volume threshold before interpreting small regions.
SELECT
	b.region,
    COUNT(DISTINCT b.borrower_id) AS borrower_count,
    COUNT(l.loan_id) AS loan_count,
    SUM(l.loan_amount) AS exposure,
    ROUND(AVG(b.credit_score),2) AS avg_credit_score,
    SUM(l.default_flag) AS defaulted_loans,
	ROUND(100.0 * SUM(l.default_flag) / COUNT(l.loan_id),2) AS default_rate_percent,
    CASE WHEN COUNT(l.loan_id)>=50 THEN 'Sufficient Volume' ELSE 'Small Volume' END AS volume_category
FROM borrowers b
JOIN loans l ON b.borrower_id = l.borrower_id
GROUP BY b.region
ORDER BY loan_count DESC;

# 18. Create utilization bands and compare default rate and exposure. Check whether the pattern remains similar across major loan types.
WITH utilization_segments AS (
	SELECT
		CASE
			WHEN ch.credit_utilization < 0.30 THEN 'Low'
            WHEN ch.credit_utilization < 0.50 THEN 'Moderate'
            WHEN ch.credit_utilization < 0.7 THEN 'High'
            WHEN ch.credit_utilization >=0.70 THEN 'Very High'
		END AS utilization_band,
        l.loan_id,
        l.loan_type,
        l.loan_amount,
        l.default_flag
	FROM credit_history ch
    JOIN loans l ON ch.borrower_id = l.borrower_id
)

SELECT
    loan_type,
    utilization_band,
    COUNT(*) AS loan_count,
    SUM(loan_amount) AS total_exposure,
    SUM(default_flag) AS default_count,

    ROUND(
        100.0 * SUM(default_flag) / COUNT(*),
        2
    ) AS default_rate_percent

FROM utilization_segments

WHERE utilization_band <> 'Unknown'

GROUP BY
    loan_type,
    utilization_band

ORDER BY
    loan_type,
    CASE utilization_band
        WHEN 'Low' THEN 1
        WHEN 'Moderate' THEN 2
        WHEN 'High' THEN 3
        WHEN 'Very High' THEN 4
    END;

# 19. Create a query that returns loans that are active and either have recent delinquency/missed payments or belong to a high-risk project-defined profile. Document the logic.
WITH latest_dataset_date AS (
    SELECT MAX(payment_date) AS max_payment_date
    FROM loan_payments
),

latest_payment AS (
    SELECT
        loan_id,
        payment_date,
        payment_status,
        days_past_due,

        ROW_NUMBER() OVER (
            PARTITION BY loan_id
            ORDER BY payment_date DESC, payment_id DESC
        ) AS rn

    FROM loan_payments
    WHERE payment_date IS NOT NULL
),

borrower_exposure AS (
    SELECT
        borrower_id,
        SUM(loan_amount) AS total_loan_exposure
    FROM loans
    GROUP BY borrower_id
),

overall_exposure AS (
    SELECT
        AVG(total_loan_exposure) AS avg_borrower_exposure
    FROM borrower_exposure
),

risk_profile AS (
    SELECT
        b.borrower_id,

        CASE
            WHEN b.credit_score < 660 THEN 1
            ELSE 0
        END AS low_credit_score,

        CASE
            WHEN ch.credit_utilization > 0.70 THEN 1
            ELSE 0
        END AS high_utilization,

        CASE
            WHEN b.annual_income > 0
             AND b.existing_debt / b.annual_income > 0.50
            THEN 1
            ELSE 0
        END AS high_debt_to_income,

        CASE
            WHEN COALESCE(be.total_loan_exposure, 0)
                 > oe.avg_borrower_exposure
            THEN 1
            ELSE 0
        END AS high_loan_exposure

    FROM borrowers b

    LEFT JOIN credit_history ch
        ON b.borrower_id = ch.borrower_id

    LEFT JOIN borrower_exposure be
        ON b.borrower_id = be.borrower_id

    CROSS JOIN overall_exposure oe
),

risk_assessment AS (
    SELECT
        borrower_id,

        (
            low_credit_score
            + high_utilization
            + high_debt_to_income
            + high_loan_exposure
        ) AS risk_condition_count

    FROM risk_profile
)

SELECT
    l.loan_id,
    l.borrower_id,
    l.loan_type,
    l.loan_amount,
    l.loan_status,

    lp.payment_date AS latest_payment_date,
    lp.payment_status AS latest_payment_status,
    lp.days_past_due AS latest_days_past_due,

    ra.risk_condition_count,

    CASE
        WHEN lp.payment_status IN ('Missed', 'Delinquent')
             AND lp.payment_date >= DATE_SUB(
                 d.max_payment_date,
                 INTERVAL 90 DAY
             )
        THEN 'Recent Payment Problem'

        WHEN ra.risk_condition_count >= 2
        THEN 'High-Risk Profile'

        ELSE 'Other'
    END AS risk_reason

FROM loans l

LEFT JOIN latest_payment lp
    ON l.loan_id = lp.loan_id
    AND lp.rn = 1

LEFT JOIN risk_assessment ra
    ON l.borrower_id = ra.borrower_id

CROSS JOIN latest_dataset_date d

WHERE
    l.loan_status = 'Active'

    AND (
        (
            lp.payment_status IN ('Missed', 'Delinquent')
            AND lp.payment_date >= DATE_SUB(
                d.max_payment_date,
                INTERVAL 90 DAY
            )
        )

        OR

        ra.risk_condition_count >= 2
    )

ORDER BY
    risk_reason,
    l.loan_amount DESC;
    
# 20. Calculate the percentage of total exposure represented by the top 10% of borrowers by exposure.
WITH borrower_exposure AS (
	SELECT
		borrower_id,
        SUM(loan_amount) AS total_exposure
	FROM loans
    GROUP BY borrower_id
),
borrower_deciles AS (
	SELECT
		borrower_id,
        total_exposure,
        NTILE(10) OVER (ORDER BY total_exposure DESC) AS exposure_pct
	FROM borrower_exposure
)

SELECT
    COUNT(*) AS top_10_percent_borrowers,

    SUM(
        CASE
            WHEN exposure_pct = 1
            THEN total_exposure
            ELSE 0
        END
    ) AS top_10_percent_exposure,

    SUM(total_exposure) AS total_borrower_exposure,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN exposure_pct = 1
                THEN total_exposure
                ELSE 0
            END
        )
        / SUM(total_exposure),
        2
    ) AS top_10_percent_exposure_share

FROM borrower_deciles;
