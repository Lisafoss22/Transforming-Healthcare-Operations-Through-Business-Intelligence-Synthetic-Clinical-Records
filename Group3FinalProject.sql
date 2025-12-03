CREATE TABLE DimPatient AS
SELECT
    ROW_NUMBER() OVER () AS patient_key,
    field1 AS patient_name,
    CAST(field2 AS INTEGER) AS age,
    field3 AS gender,
    field4 AS blood_type,
    field5 AS medical_condition
FROM (
    SELECT DISTINCT
        field1, field2, field3, field4, field5
    FROM StagingUnitedHealthcare
);

CREATE TABLE DimProvider AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY doctor, hospital) AS provider_key,
    doctor,
    hospital
FROM (
    SELECT DISTINCT 
        field7 AS doctor,
        field8 AS hospital
    FROM StagingUnitedHealthcare
);

CREATE TABLE DimPayer AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY insurance_provider) AS payer_key,
    insurance_provider
FROM (
    SELECT DISTINCT 
        field9 AS insurance_provider
    FROM StagingUnitedHealthcare
);

CREATE TABLE DimService AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY admission_type, medication, test_results) AS service_key,
    admission_type,
    medication,
    test_results
FROM (
    SELECT DISTINCT
        field12 AS admission_type,
        field14 AS medication,
        field15 AS test_results
    FROM StagingUnitedHealthcare
);

CREATE TABLE DimTime AS
SELECT
    ROW_NUMBER() OVER (ORDER BY date) AS time_key,
    date,
    SUBSTR(date, 7, 4) AS year,
    SUBSTR(date, 4, 2) AS month,
    SUBSTR(date, 1, 2) AS day
FROM (
    SELECT DISTINCT field6 AS date FROM StagingUnitedHealthcare
    UNION
    SELECT DISTINCT field13 AS date FROM StagingUnitedHealthcare
);

CREATE TABLE FactClaims AS
SELECT
    p.patient_key,
    pr.provider_key,
    s.service_key,
    pa.payer_key,
    ta.time_key AS admission_date_key,
    td.time_key AS discharge_date_key,
    CAST(st.field10 AS INTEGER) AS billing_amount,
    st.field11 AS room_number
FROM StagingUnitedHealthcare st
JOIN DimPatient p
    ON st.field1 = p.patient_name
JOIN DimProvider pr
    ON st.field7 = pr.doctor 
   AND st.field8 = pr.hospital
JOIN DimService s
    ON st.field12 = s.admission_type
   AND st.field14 = s.medication
   AND st.field15 = s.test_results
JOIN DimTime ta 
    ON st.field6 = ta.date   
JOIN DimTime td 
    ON st.field13 = td.date    
JOIN DimPayer pa
    ON st.field9 = pa.insurance_provider;

	
SELECT COUNT(*) FROM DimPatient;
SELECT COUNT(*) FROM DimProvider;
SELECT COUNT(*) FROM DimPayer;
SELECT COUNT(*) FROM DimService;
SELECT COUNT(*) FROM DimTime;
SELECT COUNT(*) FROM FactClaims;

SELECT COUNT(*) FROM FactClaims WHERE patient_key IS NULL;
SELECT COUNT(*) FROM FactClaims WHERE provider_key IS NULL;
SELECT COUNT(*) FROM FactClaims WHERE payer_key IS NULL;
SELECT COUNT(*) FROM FactClaims WHERE service_key IS NULL;
SELECT COUNT(*) FROM FactClaims WHERE admission_date_key IS NULL;
SELECT COUNT(*) FROM FactClaims WHERE discharge_date_key IS NULL;

--Patient Age Distribution (5-Year Bins)
SELECT 
    ((age - 10) / 5) * 5 + 10 AS age_bin,
    COUNT(*) AS patient_count
FROM DimPatient
WHERE age >= 10  
GROUP BY age_bin
ORDER BY age_bin;

--Age Group Contribution to Billing
SELECT
    (p.age / 10) * 10 AS age_group,
    SUM(f.billing_amount) AS total_billing
FROM FactClaims f
JOIN DimPatient p USING (patient_key)
GROUP BY age_group
ORDER BY age_group;

--How Treatment Duration Varies by Condition
SELECT
    p.medical_condition,
    f.admission_date,
    f.discharge_date
FROM FactClaims f
JOIN DimPatient p USING (patient_key);

--Length of Stay by Admission Type
SELECT
    s.admission_type,
    f.admission_date,
    f.discharge_date
FROM FactClaims f
JOIN DimService s USING (service_key);

--Patients by Condition & Gender
SELECT
    p.medical_condition,
    p.gender,
    COUNT(*) AS total_patients
FROM DimPatient p
GROUP BY p.medical_condition, p.gender
ORDER BY p.medical_condition;

--Billing Amount Distribution Across Age Groups
SELECT
    (p.age / 10) * 10 AS age_group,
    f.billing_amount
FROM FactClaims f
JOIN DimPatient p USING (patient_key);

--Top 10 Costliest Hospitals
SELECT
    pr.hospital,
    SUM(f.billing_amount) AS total_billing
FROM FactClaims f
JOIN DimProvider pr USING (provider_key)
GROUP BY pr.hospital
ORDER BY total_billing DESC
LIMIT 10;

--Billing Amount vs Patient Discharges (Monthly Trend)
SELECT
    t.year,
    t.month,
    COUNT(*) AS discharge_count,
    SUM(f.billing_amount) AS billing_total
FROM FactClaims f
JOIN DimTime t 
    ON f.discharge_date_key = t.time_key
GROUP BY t.year, t.month
ORDER BY t.year, t.month;

--Insurance Provider Revenue Contribution
SELECT
    pa.insurance_provider,
    AVG(f.billing_amount) AS avg_billing,
    COUNT(*) AS patient_count
FROM FactClaims f
JOIN DimPayer pa USING (payer_key)
GROUP BY pa.insurance_provider
ORDER BY avg_billing DESC;

--Hospital Billing vs Patient Volume (Scatter Plot)
SELECT
    pr.hospital,
    COUNT(*) AS patient_volume,
    SUM(f.billing_amount) AS total_billing
FROM FactClaims f
JOIN DimProvider pr USING (provider_key)
GROUP BY pr.hospital;

--Admissions vs Avg Billing Over Time
SELECT
    t.year,
    t.month,
    COUNT(*) AS total_admissions,
    AVG(f.billing_amount) AS avg_billing
FROM FactClaims f
JOIN DimTime t 
    ON f.admission_date_key = t.time_key
GROUP BY t.year, t.month
ORDER BY t.year, t.month;

--Top 10 Doctors by Billing Contribution
SELECT
    pr.doctor,
    SUM(f.billing_amount) AS total_billing,
    COUNT(*) AS patients
FROM FactClaims f
JOIN DimProvider pr USING (provider_key)
GROUP BY pr.doctor
ORDER BY total_billing DESC
LIMIT 10;














