/* WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
 WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
  WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING

  

  _____                      _                        _                             _            _   _             
 |  __ \                    | |                      (_)                           | |          | | (_)            
 | |  | | ___    _ __   ___ | |_   _ __ _   _ _ __    _ _ __    _ __  _ __ ___   __| |_   _  ___| |_ _  ___  _ __  
 | |  | |/ _ \  | '_ \ / _ \| __| | '__| | | | '_ \  | | '_ \  | '_ \| '__/ _ \ / _` | | | |/ __| __| |/ _ \| '_ \ 
 | |__| | (_) | | | | | (_) | |_  | |  | |_| | | | | | | | | | | |_) | | | (_) | (_| | |_| | (__| |_| | (_) | | | |
 |_____/ \___/  |_| |_|\___/ \__| |_|   \__,_|_| |_| |_|_| |_| | .__/|_|  \___/ \__,_|\__,_|\___|\__|_|\___/|_| |_|
                                                               | |                                                 
                                                               |_|                                                 


 WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
 WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING
  WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING */
/* Flushing the system so we work on cold memory */
USE master;

CHECKPOINT;
GO

DBCC DROPCLEANBUFFERS;
GO

SELECT @@VERSION;

/* Drop temp tables to allow multiple runs in same window */
IF OBJECT_ID('old') IS NOT NULL
	DROP TABLE old;

IF OBJECT_ID('new') IS NOT NULL
	DROP TABLE new;

IF OBJECT_ID('OriginalData') IS NOT NULL
	DROP TABLE OriginalData;

CREATE TABLE OriginalData (ID INT PRIMARY KEY IDENTITY(1, 1), id1 INT, id2 INT);

IF OBJECT_ID('ReplacementData') IS NOT NULL
	DROP TABLE ReplacementData;

CREATE TABLE ReplacementData (ID INT PRIMARY KEY IDENTITY(1, 1), id1 INT, id2 INT);

DECLARE @Scenario SMALLINT;
DECLARE @ScenarioGoal VARCHAR(Max);
DECLARE @ScenarioCriteria VARCHAR(Max);
DECLARE @Method VARCHAR(Max);
DECLARE @ExpectedResults VARCHAR(Max);
DECLARE @PerformanceTesting VARCHAR(Max);

-- Set this flag from 1-9 to test scenarios 1 thru 9.
SET @Scenario = 3;

IF @Scenario = 1
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- All records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are no default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: 
Matching oid1 to nid1 and oid2 to nid2 between the old and new and ignoring the aggregate to find out
what only exists in ReplacementData.'
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2
3	 |	 2
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2
	FROM new n
	LEFT JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL;

	-- Query 2
	SELECT n.nid1, n.nid2
	FROM new n
	WHERE NOT EXISTS (
			SELECT 1
			FROM old o
			WHERE o.oid1 = n.nid1
				AND o.oid2 = n.nid2
			);

	-- Query 3
	SELECT nid1, nid2
	FROM new
	WHERE nid1 NOT IN (
			SELECT oid1
			FROM old
			)
		AND nid2 NOT IN (
			SELECT oid2
			FROM old
			);

	-- Query 4
	SELECT nid1, nid2
	FROM new
	
	EXCEPT
	
	SELECT oid1, oid2
	FROM old;

	-- Query 5
	SELECT nid1, nid2
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2
		FROM old o
		WHERE o.oid1 = n.nid1
			AND o.oid2 = n.nid2
		) a
	WHERE a.oid1 IS NULL
		AND a.oid2 IS NULL;
END;
ELSE IF @Scenario = 2
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- All records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: 
	Matching oid1 to nid1 and oid2 to nid2 between the old and new and ignoring the aggregate to find out
what only exists in ReplacementData. '
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2
3	 |	 2
NUL  |   2
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1), (NULL, NULL), (1, NULL);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2), (NULL, NULL), (1, NULL), (NULL, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
		AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND (
			ISNULL(o.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(o.oid2, '') <> ISNULL(n.nid2, '')
			);

	-- Query 2
	SELECT n.nid1, n.nid2
	FROM new n
	WHERE NOT EXISTS (
			SELECT 1
			FROM old o
			WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
				AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
			);

	-- Query 3
	SELECT nid1, nid2
	FROM new
	
	EXCEPT
	
	SELECT oid1, oid2
	FROM old;

	-- Query 4
	SELECT nid1, nid2
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2
		FROM old o
		WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
			AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
		) a
	WHERE a.oid1 IS NULL
		AND a.oid2 IS NULL
		AND (
			ISNULL(a.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(a.oid2, '') <> ISNULL(n.nid2, '')
			);
END;
ELSE IF @Scenario = 3
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- Not all records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1 and oid2 to nid2 between the old and new and ignoring the aggregate to find out
what only exists in ReplacementData. '
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2
3	 |	 2
NUL  |   2
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1), (NULL, NULL), (1, NULL), (10, 10);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2), (NULL, NULL), (1, NULL), (NULL, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
		AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND (
			ISNULL(o.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(o.oid2, '') <> ISNULL(n.nid2, '')
			);

	-- Query 2
	SELECT n.nid1, n.nid2
	FROM new n
	WHERE NOT EXISTS (
			SELECT 1
			FROM old o
			WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
				AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
			);

	-- Query 3
	SELECT nid1, nid2
	FROM new
	
	EXCEPT
	
	SELECT oid1, oid2
	FROM old;

	-- Query 4
	SELECT nid1, nid2
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2
		FROM old o
		WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
			AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
		) a
	WHERE a.oid1 IS NULL
		AND a.oid2 IS NULL
		AND (
			ISNULL(a.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(a.oid2, '') <> ISNULL(n.nid2, '')
			);
END;
ELSE IF @Scenario = 4
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- All records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are no default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1, oid2 to nid2, and the count of records found between the old and new find what
 only exists in ReplacementData.'
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2	|    nc
1	 |	 1		|	 3
3	 |   2		|	 1
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	LEFT JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
		AND n.nc = o.oc
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND o.oc IS NULL;

	-- Query 2
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	WHERE NOT EXISTS (
			SELECT 1
			FROM old o
			WHERE o.oid1 = n.nid1
				AND o.oid2 = n.nid2
				AND o.oc = n.nc
			);

	-- Query 3
	SELECT nid1, nid2, nc
	FROM new
	WHERE nid1 NOT IN (
			SELECT oid1
			FROM old
			)
		OR nid2 NOT IN (
			SELECT oid2
			FROM old
			)
		OR nc NOT IN (
			SELECT oc
			FROM old
			);

	-- Query 4
	SELECT nid1, nid2, nc
	FROM new
	
	EXCEPT
	
	SELECT oid1, oid2, oc
	FROM old;

	-- Query 5
	SELECT nid1, nid2, nc
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2, o.oc
		FROM old o
		WHERE o.oid1 = n.nid1
			AND o.oid2 = n.nid2
			AND o.oc = n.nc
		) a
	WHERE a.oid1 IS NULL
		AND a.oid2 IS NULL;
END;
ELSE IF @Scenario = 5
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- All records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1, oid2 to nid2, and the count of records found between the old and new find what
 only exists in ReplacementData. '
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2	|    nc
1	 |	 1		|	 3
3	 |   2		|	 1
NUL	 |   2		|	 1
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1), (NULL, NULL), (1, NULL);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2), (NULL, NULL), (1, NULL), (NULL, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
		AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
		AND o.oc = n.nc
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND (
			ISNULL(o.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(o.oid2, '') <> ISNULL(n.nid2, '')
			);

	-- Query 2
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	WHERE NOT EXISTS (
			SELECT 1
			FROM old o
			WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
				AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
				AND o.oc = n.nc
			);

	-- Query 3
	SELECT nid1, nid2, nc
	FROM new
	
	EXCEPT
	
	SELECT oid1, oid2, oc
	FROM old;

	-- Query 4
	SELECT nid1, nid2, nc
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2
		FROM old o
		WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
			AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
			AND o.oc = n.nc
		) a
	WHERE a.oid1 IS NULL
		AND a.oid2 IS NULL
		AND (
			ISNULL(a.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(a.oid2, '') <> ISNULL(n.nid2, '')
			);
END;
ELSE IF @Scenario = 6
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- Not all records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1, oid2 to nid2, and the count of records found between the old and new find what
 only exists in ReplacementData. '
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2	|    nc
1	 |	 1		|	 3
3	 |   2		|	 1
NUL	 |   2		|	 1
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1), (NULL, NULL), (1, NULL), (10, 10);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2), (NULL, NULL), (1, NULL), (NULL, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
		AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
		AND o.oc = n.nc
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND (
			ISNULL(o.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(o.oid2, '') <> ISNULL(n.nid2, '')
			);

	-- Query 2
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	WHERE NOT EXISTS (
			SELECT 1
			FROM old o
			WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
				AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
				AND o.oc = n.nc
			);

	-- Query 3
	SELECT nid1, nid2, nc
	FROM new
	
	EXCEPT
	
	SELECT oid1, oid2, oc
	FROM old;

	-- Query 4
	SELECT nid1, nid2, nc
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2
		FROM old o
		WHERE ISNULL(o.oid1, '') = ISNULL(n.nid1, '')
			AND ISNULL(o.oid2, '') = ISNULL(n.nid2, '')
			AND o.oc = n.nc
		) a
	WHERE a.oid1 IS NULL
		AND a.oid2 IS NULL
		AND (
			ISNULL(a.oid1, '') <> ISNULL(n.nid1, '')
			OR ISNULL(a.oid2, '') <> ISNULL(n.nid2, '')
			);
END;
ELSE IF @Scenario = 7
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- All records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are no default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1 and oid2 to nid2 between the old and new. When I have found matches, I need to compare the
aggregate count. We are treating a record as an entry into ReplacementData of ID1 and ID2. If we had two counts of this record in 
ReplacementData and one count of this record in OriginalData, I would say the ReplacementData table has
one additional record of ID1 and ID2 than the OriginalData table had.'
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2	|    nc
1	 |	 1		|	 1
3	 |   2		|	 1
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2, CASE 
			WHEN (o.oc < n.nc)
				THEN (n.nc - o.oc)
			ELSE n.nc
			END AS nc
	FROM new n
	LEFT JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
	WHERE (
			o.oid1 IS NULL
			AND o.oid2 IS NULL
			)
		OR o.oc < n.nc;

	--	Query 2
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	LEFT JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
	
	UNION
	
	SELECT n.nid1, n.nid2, (n.nc - o.oc) AS nc
	FROM new n
	INNER JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
	WHERE o.oc < n.nc;

	-- Query 3
	SELECT nid1, nid2, CASE 
			WHEN (a.oc < n.nc)
				THEN (n.nc - a.oc)
			ELSE n.nc
			END AS nc
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2, o.oc
		FROM old o
		WHERE o.oid1 = n.nid1
			AND o.oid2 = n.nid2
		) a
	WHERE (
			a.oid1 IS NULL
			AND a.oid2 IS NULL
			)
		OR a.oc < n.nc;
END;
ELSE IF @Scenario = 8
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- All records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records than the OriginalData table.
- There are default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1 and oid2 to nid2 between the old and new. When I have found matches, I need to compare the
aggregate count. We are treating a record as an entry into ReplacementData of ID1 and ID2. If we had two counts of this record in 
ReplacementData and one count of this record in OriginalData, I would say the ReplacementData table has
one additional record of ID1 and ID2 than the OriginalData table had.'
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2	|    nc
1	 |	 1		|	 1
3	 |   2		|	 1
NUL	 |	 2		|	 1
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1), (NULL, NULL), (1, NULL);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2), (NULL, NULL), (1, NULL), (NULL, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2, CASE 
			WHEN (o.oc < n.nc)
				THEN (n.nc - o.oc)
			ELSE n.nc
			END AS nc
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = isnull(n.nid1, '')
		AND isnull(o.oid2, '') = isnull(n.nid2, '')
	WHERE (
			o.oid1 IS NULL
			AND o.oid2 IS NULL
			)
		AND isnull(o.oc, '') <> isnull(n.nc, '')
		OR o.oc < n.nc;

	--	Query 2
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = isnull(n.nid1, '')
		AND isnull(o.oid2, '') = isnull(n.nid2, '')
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND isnull(o.oc, '') <> isnull(n.nc, '')
	
	UNION
	
	SELECT n.nid1, n.nid2, (n.nc - o.oc) AS nc
	FROM new n
	INNER JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
	WHERE o.oc < n.nc;

	-- Query 3
	SELECT nid1, nid2, CASE 
			WHEN (a.oc < n.nc)
				THEN (n.nc - a.oc)
			ELSE n.nc
			END AS nc
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2, o.oc
		FROM old o
		WHERE isnull(o.oid1, '') = isnull(n.nid1, '')
			AND isnull(o.oid2, '') = isnull(n.nid2, '')
		) a
	WHERE (
			a.oid1 IS NULL
			AND a.oid2 IS NULL
			)
		AND isnull(a.oc, '') <> isnull(n.nc, '')
		OR a.oc < n.nc;
END;
ELSE IF @Scenario = 9
BEGIN
	SET @ScenarioGoal = 'Goal: We have rows in new and old, we want to know what records exist in ReplacementData but not in OriginalData.'
	SET @ScenarioCriteria = 'Criteria:
- Not all records that exist in OriginalData will exist in ReplacementData.
- ReplacementData will have more records in that table than in the OriginalData table.
- There are default values, blank values, or NULL that exist in OriginalData or ReplacementData.'
	SET @Method = 'Method: Matching oid1 to nid1 and oid2 to nid2 between the old and new. When I have found matches, I need to compare the
aggregate count. We are treating a record as an entry into ReplacementData of ID1 and ID2. If we had two counts of this record in 
ReplacementData and one count of this record in OriginalData, I would say the ReplacementData table has
one additional record of ID1 and ID2 than the OriginalData table had.'
	SET @ExpectedResults = 'Expected Result Set from data input:
ReplacementData
ID1	 |	 ID2	|    nc
1	 |	 1		|	 1
3	 |   2		|	 1
NUL	 |	 2		|	 1
'
	SET @PerformanceTesting = 'Performance Testing:
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
'

	PRINT 'Scenario ' + cast(@Scenario AS CHAR(2));
	PRINT @ScenarioGoal;
	PRINT @ScenarioCriteria;
	PRINT @Method;
	PRINT @ExpectedResults;
	PRINT @PerformanceTesting;

	/* Add values to primary tables */
	INSERT INTO OriginalData (id1, id2)
	VALUES (1, 1), (1, 1), (2, 1), (NULL, NULL), (1, NULL), (10, 10);

	INSERT INTO ReplacementData (id1, id2)
	VALUES (1, 1), (1, 1), (1, 1), (2, 1), (3, 2), (NULL, NULL), (1, NULL), (NULL, 2);

	/* Add values to new tables */
	SELECT id1 AS oid1, id2 AS oid2, COUNT(*) AS oc
	INTO old
	FROM OriginalData
	GROUP BY id1, id2;

	SELECT id1 AS nid1, id2 AS nid2, COUNT(*) AS nc
	INTO new
	FROM ReplacementData
	GROUP BY id1, id2;

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;
	SET STATISTICS XML ON;

	-- Query 1
	SELECT n.nid1, n.nid2, CASE 
			WHEN (o.oc < n.nc)
				THEN (n.nc - o.oc)
			ELSE n.nc
			END AS nc
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = isnull(n.nid1, '')
		AND isnull(o.oid2, '') = isnull(n.nid2, '')
	WHERE (
			o.oid1 IS NULL
			AND o.oid2 IS NULL
			)
		AND isnull(o.oc, '') <> isnull(n.nc, '')
		OR o.oc < n.nc;

	--	Query 2
	SELECT n.nid1, n.nid2, n.nc
	FROM new n
	LEFT JOIN old o ON ISNULL(o.oid1, '') = isnull(n.nid1, '')
		AND isnull(o.oid2, '') = isnull(n.nid2, '')
	WHERE o.oid1 IS NULL
		AND o.oid2 IS NULL
		AND isnull(o.oc, '') <> isnull(n.nc, '')
	
	UNION
	
	SELECT n.nid1, n.nid2, (n.nc - o.oc) AS nc
	FROM new n
	INNER JOIN old o ON o.oid1 = n.nid1
		AND o.oid2 = n.nid2
	WHERE o.oc < n.nc;

	-- Query 3
	SELECT nid1, nid2, CASE 
			WHEN (a.oc < n.nc)
				THEN (n.nc - a.oc)
			ELSE n.nc
			END AS nc
	FROM new n
	OUTER APPLY (
		SELECT o.oid1, o.oid2, o.oc
		FROM old o
		WHERE isnull(o.oid1, '') = isnull(n.nid1, '')
			AND isnull(o.oid2, '') = isnull(n.nid2, '')
		) a
	WHERE (
			a.oid1 IS NULL
			AND a.oid2 IS NULL
			)
		AND isnull(a.oc, '') <> isnull(n.nc, '')
		OR a.oc < n.nc;
END;
ELSE IF @Scenario NOT LIKE '%[1-9]'
BEGIN
	PRINT 'Please enter a valid scenario'
END;
