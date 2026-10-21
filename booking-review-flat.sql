/*
 * Standalone, read-only Oracle SQL prototype for a flat CSV export.
 * Run in the schema that exposes the existing ICMS/cRDS tables and views.
 * One row per Active ICMS booking record. Companies with no Active bookings
 * and requested IDs not found in ICMS have an explicit non-booking row.
 *
 * Edit Parameters and InputIds only:
 *   FLAGGED = the existing baseline multi-parent cohort (count is not fixed).
 *   ALL     = every ICMS entity, including inactive entities.
 *   IDS     = the IDs in InputIds, independent of whether they are flagged.
 * entity_limit limits companies, never booking rows. NULL means no limit.
 *
 * Export ALL result rows; compare the CSV row count with expected_result_rows.
 * Do not use a preview, cancelled query or truncated CSV as complete evidence.
 * Counts are pre-aggregated before joins. Repeated company/parent totals must
 * not be summed over booking rows. This is not an evidence-bundle replacement.
 * SQL logic is locally tested; Oracle execution and live parity are pending.
 */
WITH Parameters AS (
    SELECT 'FLAGGED' AS selection_mode,
           CAST(NULL AS NUMBER) AS entity_limit
    FROM dual
), InputIds AS (
    SELECT 3 AS le_id FROM dual UNION ALL
    SELECT 47 FROM dual UNION ALL
    SELECT 248 FROM dual UNION ALL
    SELECT 894 FROM dual
), EntityIds AS (
    SELECT le.id AS le_id
    FROM prd_export_legal_entity le CROSS JOIN Parameters cfg
    WHERE cfg.selection_mode IN ('ALL', 'FLAGGED')
    UNION
    SELECT i.le_id FROM InputIds i CROSS JOIN Parameters cfg
    WHERE cfg.selection_mode = 'IDS'
), EntityHeaders AS (
    SELECT ids.le_id, COUNT(le.id) AS entity_source_rows,
           CASE WHEN COUNT(le.id) = 1 THEN MAX(le.name) END AS company_name,
           CASE WHEN COUNT(le.id) = 1 THEN MAX(le.status) END AS company_status
    FROM EntityIds ids LEFT JOIN prd_export_legal_entity le ON le.id = ids.le_id
    GROUP BY ids.le_id
), SystemMappings AS (
    SELECT id, COUNT(*) AS mapping_rows,
           CASE WHEN COUNT(*) = 1 THEN MAX(name) END AS system_name,
           CASE WHEN COUNT(*) = 1 THEN MAX(crds_system_id) END AS crds_system_id
    FROM t_crds_booking_system GROUP BY id
), SettlementMethods AS (
    SELECT id, COUNT(*) AS method_rows,
           CASE WHEN COUNT(*) = 1 THEN MAX(name) END AS method_name
    FROM t_settlement_method GROUP BY id
), BookingRecords AS (
    SELECT bc.le_id, bc.id AS booking_record_id, COUNT(*) AS booking_source_rows,
           CASE WHEN COUNT(*) = 1 THEN MAX(bc.booking_code) END AS booking_code,
           CASE WHEN COUNT(*) = 1 THEN MAX(bc.settlement_system_id) END AS settlement_system_id,
           CASE WHEN COUNT(*) = 1 THEN MAX(bc.settlement_method) END AS settlement_method_id,
           CASE WHEN COUNT(*) = 1 THEN MAX(bc.crds_id) END AS assigned_crds_id,
           CASE WHEN COUNT(*) = 1 THEN MAX(bc.activated_db_le_id) END AS activated_db_le_id,
           CASE WHEN COUNT(*) = 1 THEN MAX(bc.db_le_override_src) END AS override_source
    FROM prd_export_booking_code bc JOIN EntityHeaders e ON e.le_id = bc.le_id
    WHERE bc.status = 'Active' AND e.entity_source_rows = 1
    GROUP BY bc.le_id, bc.id
), ActiveBookings AS (
    SELECT b.*, sm.system_name, sm.crds_system_id,
           NVL(sm.mapping_rows, 0) AS system_mapping_rows,
           m.method_name, NVL(m.method_rows, 0) AS method_lookup_rows
    FROM BookingRecords b
    LEFT JOIN SystemMappings sm ON sm.id = b.settlement_system_id
    LEFT JOIN SettlementMethods m ON m.id = b.settlement_method_id
), ActiveKeys AS (
    SELECT DISTINCT booking_code, crds_system_id FROM ActiveBookings
    WHERE booking_code IS NOT NULL AND crds_system_id IS NOT NULL
), RawPaths AS (
    -- Keep broken/inactive chains for status evidence. Full chains alone
    -- participate in the existing baseline/current parent selection below.
    SELECT ax.systemaccountid AS booking_code, ps.systemid AS system_id,
           ae.adoptionentityaminetid AS aminet_id,
           br.holderpartyid AS rhp_id, h.ultimate_parent_id,
           up.party_id AS report_parent_id,
           ax.accountxrefstatus AS xref_status,
           ax.accountxrefstatusdate AS xref_status_date,
           ps.productsystemstatus AS product_system_status,
           pa.productadoptionstatus AS product_adoption_status,
           ae.adoptionentitystatus AS adoption_entity_status,
           al.adoptionlocationstatus AS adoption_location_status,
           br.status AS relationship_status,
           h.party_hierarchy_status_code AS hierarchy_status,
           CASE WHEN h.party_id IS NULL THEN NULL
                WHEN h.party_hierarchy_end_date < SYSTIMESTAMP THEN 1 ELSE 0 END AS hierarchy_ended,
           CASE ax.accountxrefstatus WHEN 'ACTIVE' THEN 1 ELSE 2 END AS status_rank,
           GREATEST(NVL(ax.accountxrefstatusdate, SYSTIMESTAMP),
                    NVL(br.statusdate, SYSTIMESTAMP),
                    NVL(ae.adoptionentitystatusdate, SYSTIMESTAMP),
                    NVL(al.adoptionlocationstatusdate, SYSTIMESTAMP),
                    NVL(pa.productadoptionstatusdate, SYSTIMESTAMP)) AS recency,
           CASE WHEN pa.productadoptionuniqueid IS NOT NULL
                     AND ae.adoptionentityuniqueid IS NOT NULL
                     AND al.adoptionlocationuniqueid IS NOT NULL
                     AND br.id IS NOT NULL AND rp.party_id IS NOT NULL
                     AND h.party_id IS NOT NULL THEN 1 ELSE 0 END AS full_parent_path
    FROM crds_br_account_xref ax
    JOIN crds_br_product_system ps ON ps.productsystemuniqueid = ax.brps_id
    LEFT JOIN crds_br_product_adoption pa ON pa.productadoptionuniqueid = ps.brpa_id
    LEFT JOIN crds_br_adoption_entity ae ON ae.adoptionentityuniqueid = pa.bre_id
    LEFT JOIN crds_br_adoption_location al ON al.adoptionlocationuniqueid = ae.brl_id
    LEFT JOIN crds_business_relationship br ON br.id = al.brid
    LEFT JOIN crds_dif_party_base rp ON rp.party_id = br.holderpartyid
    LEFT JOIN crds_dif_party_hierarchy h ON h.party_id = br.holderpartyid AND h.primary_flag = 'Y'
    LEFT JOIN crds_dif_party_base up ON up.party_id = h.ultimate_parent_id
    WHERE ax.systemaccountid <> 'TEMP_LE'
      AND ps.systemid IN (136,140,138,150,234,237,239,308,553,554,555,205,219,
                          196,206,227,228,229,230,452,473,474,475,598,679,289,625)
      AND EXISTS (SELECT 1 FROM ActiveKeys k
                  WHERE k.booking_code = ax.systemaccountid AND k.crds_system_id = ps.systemid)
), RankedBaseline AS (
    -- Matches review-cohort.sql/review-paths-ctes.sql. Exact recency ties
    -- in this legacy rule are not deterministic; expose them, do not hide them.
    SELECT p.*,
           ROW_NUMBER() OVER (PARTITION BY system_id, booking_code, aminet_id
                             ORDER BY status_rank, recency DESC) AS baseline_rank,
           COUNT(DISTINCT NVL(report_parent_id, 0)) OVER (
               PARTITION BY system_id, booking_code, aminet_id, status_rank, recency
           ) AS parents_at_same_rank
    FROM RawPaths p WHERE full_parent_path = 1
), KeyBaseline AS (
    SELECT system_id, booking_code, COUNT(*) AS full_path_rows,
           MIN(CASE WHEN baseline_rank = 1 THEN report_parent_id END) AS baseline_parent_id,
           MAX(CASE WHEN baseline_rank = 1 AND parents_at_same_rank > 1 THEN 1 ELSE 0 END) AS baseline_tie,
           COUNT(DISTINCT NVL(ultimate_parent_id, 0)) AS all_path_parent_count
    FROM RankedBaseline GROUP BY system_id, booking_code
), EntityBaseline AS (
    SELECT b.le_id, COUNT(DISTINCT NVL(k.baseline_parent_id, 0)) AS baseline_parent_count,
           MAX(k.baseline_tie) AS baseline_has_tie
    FROM ActiveBookings b JOIN KeyBaseline k
      ON k.booking_code = b.booking_code AND k.system_id = b.crds_system_id
    GROUP BY b.le_id
), EligibleEntities AS (
    SELECT e.*, NVL(b.baseline_parent_count, 0) AS baseline_parent_count,
           NVL(b.baseline_has_tie, 0) AS baseline_has_tie,
           ROW_NUMBER() OVER (ORDER BY e.le_id) AS entity_rank
    FROM EntityHeaders e LEFT JOIN EntityBaseline b ON b.le_id = e.le_id
    CROSS JOIN Parameters cfg
    WHERE cfg.selection_mode <> 'FLAGGED' OR b.baseline_parent_count > 1
), SelectedEntities AS (
    SELECT e.* FROM EligibleEntities e CROSS JOIN Parameters cfg
    WHERE cfg.entity_limit IS NULL OR e.entity_rank <= cfg.entity_limit
), SelectedBookings AS (
    SELECT b.* FROM ActiveBookings b JOIN SelectedEntities e ON e.le_id = b.le_id
), SelectedPaths AS (
    SELECT p.* FROM RawPaths p WHERE EXISTS (
        SELECT 1 FROM SelectedBookings b
        WHERE b.booking_code = p.booking_code AND b.crds_system_id = p.system_id)
), CurrentPaths AS (
    SELECT p.*,
           ROW_NUMBER() OVER (PARTITION BY system_id, booking_code
               ORDER BY recency DESC, ultimate_parent_id, rhp_id) AS current_rank,
           COUNT(DISTINCT ultimate_parent_id) OVER (PARTITION BY system_id, booking_code) AS current_parents_on_key
    FROM SelectedPaths p
    WHERE full_parent_path = 1 AND xref_status = 'ACTIVE' AND relationship_status = 'ACTIVE'
      AND hierarchy_ended = 0 AND ultimate_parent_id IS NOT NULL
), SalesforceSummary AS (
    -- Multiple source rows stay ambiguous even when their values agree.
    SELECT TRIM(sf.crds_id) AS party_id, COUNT(*) AS sf_rows,
           CASE WHEN COUNT(*) = 1 THEN MAX(sf.name) END AS sf_name,
           CASE WHEN COUNT(*) = 1 THEN MAX(CASE WHEN sf.is_reporting_level = 1
                THEN TRIM(sf.crds_id) ELSE TRIM(sf.rep_group_crds_id) END) END AS reporting_group_id,
           CASE WHEN COUNT(*) = 1 THEN MAX(CASE WHEN sf.is_reporting_level = 1 THEN 1 ELSE 0 END) END AS reporting_level,
           CASE WHEN COUNT(*) = 1 THEN MAX(TRIM(sf.legal_ultimate_parent_crds_id)) END AS sf_legal_parent_id
    FROM prd_export_client_rep_hierarchy_v6 sf
    WHERE EXISTS (SELECT 1 FROM SelectedPaths p
                  WHERE TRIM(sf.crds_id) = CAST(p.rhp_id AS VARCHAR2(128)))
    GROUP BY TRIM(sf.crds_id)
), ReferencedParties AS (
    SELECT CAST(rhp_id AS VARCHAR2(128)) AS party_id FROM SelectedPaths
    UNION SELECT CAST(ultimate_parent_id AS VARCHAR2(128)) FROM SelectedPaths
    UNION SELECT TRIM(assigned_crds_id) FROM SelectedBookings
    UNION SELECT reporting_group_id FROM SalesforceSummary
), PartySummary AS (
    SELECT p.party_id, COUNT(*) AS party_rows,
           CASE WHEN COUNT(DISTINCT COALESCE(p.party_legal_nm, p.party_std_nm)) = 1
                THEN MIN(COALESCE(p.party_legal_nm, p.party_std_nm)) END AS party_name,
           CASE WHEN COUNT(TRIM(p.party_industry_status)) = COUNT(*)
                     AND COUNT(DISTINCT UPPER(TRIM(p.party_industry_status))) = 1
                THEN MIN(UPPER(TRIM(p.party_industry_status))) END AS industry_status,
           CASE WHEN COUNT(p.party_industry_status_dt) = COUNT(*)
                     AND MIN(p.party_industry_status_dt) = MAX(p.party_industry_status_dt)
                THEN MIN(p.party_industry_status_dt) END AS industry_status_date,
           CASE WHEN COUNT(DISTINCT p.surviving_entity_id) = 1
                THEN MIN(p.surviving_entity_id) END AS surviving_party_id
    FROM crds_dif_party_base p
    WHERE CAST(p.party_id AS VARCHAR2(128)) IN (SELECT party_id FROM ReferencedParties)
    GROUP BY p.party_id
), LeiSummary AS (
    -- Raw typed identifier observations, not a validated identity binding.
    SELECT pi.party_id, COUNT(*) AS lei_rows, COUNT(DISTINCT TRIM(pi.party_alt_id)) AS lei_values,
           CASE WHEN COUNT(DISTINCT TRIM(pi.party_alt_id)) = 1 THEN MIN(TRIM(pi.party_alt_id)) END AS observed_lei
    FROM crds_dif_party_identifiers pi
    WHERE pi.party_id_type_cd = 'LEI'
      AND CAST(pi.party_id AS VARCHAR2(128)) IN (SELECT party_id FROM ReferencedParties)
    GROUP BY pi.party_id
), StatusObservations AS (
    SELECT p.system_id, p.booking_code, p.rhp_id, p.ultimate_parent_id,
           rp.industry_status AS rhp_status, up.industry_status AS parent_status,
           UPPER(TRIM(p.xref_status)) AS booking_status,
           CASE WHEN rp.industry_status IS NULL THEN NULL
                WHEN rp.industry_status IN ('ACTIVE','IN_FORMATION') THEN 0 ELSE 1 END AS rhp_warning,
           CASE WHEN up.industry_status IS NULL THEN NULL
                WHEN up.industry_status IN ('ACTIVE','IN_FORMATION') THEN 0 ELSE 1 END AS parent_warning,
           CASE WHEN UPPER(TRIM(p.xref_status)) IN ('ACTIVE','REACTIVATING') THEN 0
                WHEN UPPER(TRIM(p.xref_status)) IN ('DELETED','INACTIVE','SUSPENDED') THEN 1 END AS booking_warning,
           CASE WHEN rp.industry_status IN ('ACTIVE','IN_FORMATION') THEN 'NO_SIGNAL'
                WHEN rp.industry_status IN ('IN_ADMINISTRATION','IN_LIQUIDATION','DELETED','INACTIVE','ABANDONED')
                 AND up.industry_status IN ('ACTIVE','IN_FORMATION') THEN 'ROWS_1_2'
                WHEN rp.industry_status IN ('IN_ADMINISTRATION','IN_LIQUIDATION','DELETED','INACTIVE','ABANDONED')
                 AND up.industry_status IN ('IN_ADMINISTRATION','IN_LIQUIDATION','DELETED','INACTIVE','ABANDONED')
                THEN 'ROWS_3_4' ELSE 'UNKNOWN' END AS party_matrix_candidates
    FROM SelectedPaths p
    LEFT JOIN PartySummary rp ON rp.party_id = p.rhp_id
    LEFT JOIN PartySummary up ON up.party_id = p.ultimate_parent_id
), StatusSummary AS (
    SELECT system_id, booking_code, COUNT(*) AS all_status_path_rows,
           COUNT(DISTINCT rhp_id) AS all_status_rhp_count,
           COUNT(DISTINCT ultimate_parent_id) AS all_status_parent_count,
           CASE WHEN COUNT(rhp_warning) = COUNT(*) AND MIN(rhp_warning) = MAX(rhp_warning)
                THEN MIN(rhp_warning) END AS rhp_warning,
           CASE WHEN COUNT(parent_warning) = COUNT(*) AND MIN(parent_warning) = MAX(parent_warning)
                THEN MIN(parent_warning) END AS parent_warning,
           CASE WHEN COUNT(booking_warning) = COUNT(*) AND MIN(booking_warning) = MAX(booking_warning)
                THEN MIN(booking_warning) END AS booking_warning,
           CASE WHEN COUNT(DISTINCT party_matrix_candidates) = 1 THEN MIN(party_matrix_candidates)
                ELSE 'MIXED_PATH_RESULTS' END AS party_matrix_candidates
    FROM StatusObservations GROUP BY system_id, booking_code
), ContactPeople AS (
    SELECT cp.le_id, cp.id,
           CASE WHEN cp.id IS NOT NULL AND COUNT(TRIM(cp.status)) = COUNT(*)
                     AND COUNT(DISTINCT UPPER(TRIM(cp.status))) = 1 THEN 1 ELSE 0 END AS valid_status,
           MAX(CASE WHEN UPPER(TRIM(cp.status)) = 'ACTIVE' THEN 1 ELSE 0 END) AS active_person
    FROM t_contact_person cp JOIN SelectedEntities e ON e.le_id = cp.le_id
    GROUP BY cp.le_id, cp.id
), ContactSummary AS (
    SELECT le_id, SUM(CASE WHEN valid_status = 0 THEN 1 ELSE 0 END) AS invalid_contacts,
           SUM(active_person) AS observed_active_contacts
    FROM ContactPeople GROUP BY le_id
), SelectedRoutings AS (
    SELECT sr.* FROM prd_export_settlement_routing sr
    JOIN SelectedEntities e ON e.le_id = sr.le_id
), RoutingSummary AS (
    -- This key excludes settlement method. A positive count is not proof
    -- of routes for the booking's particular method; zero is usable.
    SELECT sr.le_id, sr.booking_code, sr.settlement_system_id, COUNT(*) AS route_count,
           SUM(CASE WHEN UPPER(TRIM(sr.account_code)) = 'BLOCK' THEN 1 ELSE 0 END) AS block_count,
           COUNT(DISTINCT sr.account_id) AS account_count,
           SUM(CASE WHEN a.id IS NULL THEN 1 ELSE 0 END) AS missing_account_routes,
           SUM(CASE WHEN a.le_id <> sr.le_id THEN 1 ELSE 0 END) AS other_owner_routes,
           MAX(NVL(sr.updatetimestamp, sr.creationtimestamp)) AS last_routing_change
    FROM SelectedRoutings sr LEFT JOIN prd_export_account a ON a.id = sr.account_id
    GROUP BY sr.le_id, sr.booking_code, sr.settlement_system_id
), SharedOwners AS (
    SELECT b.le_id, b.booking_record_id, COUNT(DISTINCT other.le_id) AS other_entity_count
    FROM SelectedBookings b
    JOIN prd_export_booking_code other ON other.booking_code = b.booking_code
      AND other.settlement_system_id = b.settlement_system_id
      AND other.le_id <> b.le_id AND other.status = 'Active'
    JOIN prd_export_legal_entity le ON le.id = other.le_id
    GROUP BY b.le_id, b.booking_record_id
), NativeBookings AS (
    SELECT n.id, COUNT(*) AS native_rows,
           CASE WHEN COUNT(*) = 1 THEN MAX(n.le_id) END AS le_id,
           CASE WHEN COUNT(*) = 1 THEN MAX(n.booking_code) END AS booking_code,
           CASE WHEN COUNT(*) = 1 THEN MAX(n.settlement_system_id) END AS system_id
    FROM t_booking_code n
    WHERE n.id IN (SELECT booking_code_id FROM SelectedRoutings)
    GROUP BY n.id
), PlatformLinks AS (
    SELECT b.le_id, b.booking_record_id, x.id AS platform_record_id,
           x.name AS customer_name, x.bbg_firm_name AS firm_name, ep.name AS platform_name,
           CASE WHEN a.le_id IS NULL THEN 'ACCOUNT_OWNER_UNKNOWN'
                WHEN a.le_id <> b.le_id THEN 'ACCOUNT_OWNER_MISMATCH'
                WHEN sr.booking_code_id IS NULL OR n.id IS NULL OR n.native_rows <> 1 THEN 'BOOKING_KEY_ONLY'
                WHEN n.le_id = b.le_id AND n.booking_code = b.booking_code
                     AND n.system_id = b.settlement_system_id THEN 'VERIFIED_BOOKING_ID'
                ELSE 'NATIVE_BOOKING_KEY_MISMATCH' END AS link_status
    FROM SelectedBookings b
    JOIN SelectedRoutings sr ON sr.le_id = b.le_id AND sr.booking_code = b.booking_code
                           AND sr.settlement_system_id = b.settlement_system_id
    JOIN prd_export_account a ON a.id = sr.account_id
    JOIN t_account_code_on_ep x ON x.account_id = a.id
    LEFT JOIN t_eplatform ep ON ep.id = x.ep_id
    LEFT JOIN NativeBookings n ON n.id = sr.booking_code_id
), PlatformSummary AS (
    SELECT le_id, booking_record_id, COUNT(*) AS platform_link_rows,
           COUNT(DISTINCT platform_record_id) AS platform_record_count,
           COUNT(DISTINCT CASE WHEN link_status = 'VERIFIED_BOOKING_ID'
                AND (TRIM(customer_name) IS NOT NULL OR TRIM(firm_name) IS NOT NULL)
                THEN platform_record_id END) AS verified_named_records,
           COUNT(DISTINCT CASE WHEN link_status = 'BOOKING_KEY_ONLY'
                AND (TRIM(customer_name) IS NOT NULL OR TRIM(firm_name) IS NOT NULL)
                THEN platform_record_id END) AS key_only_named_records,
           COUNT(DISTINCT CASE WHEN link_status NOT IN ('VERIFIED_BOOKING_ID','BOOKING_KEY_ONLY')
                THEN platform_record_id END) AS conflict_records,
           COUNT(DISTINCT CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN TRIM(customer_name) END) AS verified_name_count,
           CASE WHEN COUNT(DISTINCT CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN TRIM(customer_name) END) = 1
                THEN MIN(CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN TRIM(customer_name) END) END AS unique_verified_name,
           COUNT(DISTINCT CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN TRIM(firm_name) END) AS verified_firm_name_count,
           CASE WHEN COUNT(DISTINCT CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN TRIM(firm_name) END) = 1
                THEN MIN(CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN TRIM(firm_name) END) END AS unique_verified_firm_name,
           CASE WHEN COUNT(DISTINCT CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN platform_name END) = 1
                THEN MIN(CASE WHEN link_status = 'VERIFIED_BOOKING_ID' THEN platform_name END) END AS unique_verified_platform
    FROM PlatformLinks GROUP BY le_id, booking_record_id
), BookingFacts AS (
    SELECT e.le_id, e.company_name, e.company_status, e.entity_source_rows,
           e.baseline_parent_count, e.baseline_has_tie,
           b.booking_record_id, b.booking_source_rows, b.booking_code,
           b.settlement_system_id, b.system_name, b.crds_system_id, b.system_mapping_rows,
           b.settlement_method_id, b.method_name, b.method_lookup_rows,
           b.assigned_crds_id, b.activated_db_le_id, b.override_source,
           CASE WHEN e.entity_source_rows = 1 AND UPPER(e.company_status) = 'ACTIVE'
                     AND b.booking_source_rows = 1 THEN 1 ELSE 0 END AS score_eligible,
           CASE WHEN b.booking_record_id IS NULL THEN 'NOT_APPLICABLE'
                WHEN b.booking_source_rows <> 1 OR b.system_mapping_rows > 1 THEN 'UNAVAILABLE'
                WHEN b.crds_system_id IS NULL THEN 'NO_CRDS_SYSTEM'
                WHEN c.ultimate_parent_id IS NOT NULL THEN 'CURRENT_PATH'
                WHEN k.full_path_rows > 0 THEN 'NO_CURRENT_PATH' ELSE 'NO_CRDS_PATH' END AS path_resolution,
           NVL(k.full_path_rows, 0) AS full_parent_path_rows,
           NVL(k.all_path_parent_count, 0) AS full_path_parent_count,
           NVL(k.baseline_tie, 0) AS key_baseline_tie,
           c.rhp_id, rp.party_name AS rhp_name, rp.industry_status AS rhp_status,
           rp.industry_status_date AS rhp_status_date, rp.surviving_party_id AS rhp_surviving_party_id,
           c.ultimate_parent_id, up.party_name AS parent_name, up.industry_status AS parent_status,
           up.industry_status_date AS parent_status_date,
           NVL(c.current_parents_on_key, 0) AS current_parents_on_key,
           c.xref_status AS current_xref_status, c.product_system_status,
           c.product_adoption_status, c.adoption_entity_status, c.adoption_location_status,
           c.relationship_status, c.hierarchy_status,
           NVL(ss.all_status_path_rows, 0) AS all_status_path_rows,
           NVL(ss.all_status_rhp_count, 0) AS all_status_rhp_count,
           NVL(ss.all_status_parent_count, 0) AS all_status_parent_count,
           ss.rhp_warning, ss.parent_warning, ss.booking_warning,
           ss.party_matrix_candidates,
           CASE WHEN e.entity_source_rows = 1 AND NVL(cp.invalid_contacts, 0) = 0
                THEN NVL(cp.observed_active_contacts, 0) END AS active_contact_count,
           CASE WHEN e.entity_source_rows = 1 AND NVL(cp.invalid_contacts, 0) = 0
                THEN 'KNOWN' ELSE 'UNKNOWN' END AS contact_count_status,
           CASE WHEN b.booking_code IS NOT NULL AND b.settlement_system_id IS NOT NULL
                THEN NVL(rt.route_count, 0) END AS wider_route_count,
           NVL(rt.block_count, 0) AS blocked_account_route_count,
           NVL(rt.account_count, 0) AS routed_account_count,
           NVL(rt.missing_account_routes, 0) AS missing_account_route_count,
           NVL(rt.other_owner_routes, 0) AS other_owner_route_count,
           rt.last_routing_change,
           NVL(sh.other_entity_count, 0) AS shared_key_other_entities,
           NVL(sf.sf_rows, 0) AS salesforce_rows, sf.reporting_group_id,
           COALESCE(gp.party_name, CASE WHEN sf.reporting_group_id = sf.party_id THEN sf.sf_name END) AS reporting_group_name,
           sf.reporting_level, sf.sf_legal_parent_id,
           rl.observed_lei AS rhp_observed_lei, NVL(rl.lei_values, 0) AS rhp_lei_value_count,
           pl.observed_lei AS parent_observed_lei, NVL(pl.lei_values, 0) AS parent_lei_value_count,
           NVL(pn.platform_link_rows, 0) AS platform_link_rows,
           NVL(pn.platform_record_count, 0) AS platform_record_count,
           NVL(pn.verified_named_records, 0) AS verified_named_records,
           NVL(pn.key_only_named_records, 0) AS key_only_named_records,
           NVL(pn.conflict_records, 0) AS platform_conflict_records,
           NVL(pn.verified_name_count, 0) AS verified_name_count,
           pn.unique_verified_name, pn.unique_verified_platform,
           NVL(pn.verified_firm_name_count, 0) AS verified_firm_name_count,
           pn.unique_verified_firm_name
    FROM SelectedEntities e LEFT JOIN SelectedBookings b ON b.le_id = e.le_id
    LEFT JOIN KeyBaseline k ON k.booking_code = b.booking_code AND k.system_id = b.crds_system_id
    LEFT JOIN CurrentPaths c ON c.booking_code = b.booking_code AND c.system_id = b.crds_system_id AND c.current_rank = 1
    LEFT JOIN StatusSummary ss ON ss.booking_code = b.booking_code AND ss.system_id = b.crds_system_id
    LEFT JOIN PartySummary rp ON rp.party_id = c.rhp_id
    LEFT JOIN PartySummary up ON up.party_id = c.ultimate_parent_id
    LEFT JOIN ContactSummary cp ON cp.le_id = e.le_id
    LEFT JOIN RoutingSummary rt ON rt.le_id = b.le_id AND rt.booking_code = b.booking_code
                               AND rt.settlement_system_id = b.settlement_system_id
    LEFT JOIN SharedOwners sh ON sh.le_id = b.le_id AND sh.booking_record_id = b.booking_record_id
    LEFT JOIN SalesforceSummary sf ON sf.party_id = CAST(c.rhp_id AS VARCHAR2(128))
    LEFT JOIN PartySummary gp ON CAST(gp.party_id AS VARCHAR2(128)) = sf.reporting_group_id
    LEFT JOIN LeiSummary rl ON rl.party_id = c.rhp_id
    LEFT JOIN LeiSummary pl ON pl.party_id = c.ultimate_parent_id
    LEFT JOIN PlatformSummary pn ON pn.le_id = b.le_id AND pn.booking_record_id = b.booking_record_id
), BookingChecks AS (
    SELECT f.*,
           CASE WHEN score_eligible = 0 OR rhp_warning IS NULL THEN 'UNKNOWN'
                WHEN rhp_warning = 1 THEN 'WARNING' ELSE 'CLEAR' END AS bc14_rhp_status,
           CASE WHEN score_eligible = 0 OR parent_warning IS NULL THEN 'UNKNOWN'
                WHEN parent_warning = 1 THEN 'WARNING' ELSE 'CLEAR' END AS bc16_parent_status,
           CASE WHEN score_eligible = 0 OR booking_warning IS NULL THEN 'UNKNOWN'
                WHEN booking_warning = 1 THEN 'WARNING' ELSE 'CLEAR' END AS bc12_booking_status,
           CASE WHEN score_eligible = 0 OR active_contact_count IS NULL THEN 'UNKNOWN'
                WHEN active_contact_count = 0 THEN 'WARNING' ELSE 'CLEAR' END AS le13_no_active_contacts,
           CASE WHEN score_eligible = 1 AND wider_route_count = 0 AND settlement_method_id IS NOT NULL
                THEN 'WARNING' ELSE 'UNKNOWN' END AS bc07_no_settlement_routes,
           'UNKNOWN' AS bc10_no_confirmation_routes,
           'UNKNOWN' AS bc21_no_recent_trades,
           CASE WHEN score_eligible = 0 THEN 'ACTIVE_ENTITY_OR_UNIQUE_BOOKING_NOT_VERIFIED'
                WHEN booking_code IS NULL OR settlement_system_id IS NULL OR settlement_method_id IS NULL
                THEN 'BOOKING_KEY_INCOMPLETE'
                WHEN wider_route_count = 0 THEN 'ZERO_OVER_WIDER_KEY_PROVES_ZERO_FOR_THIS_METHOD'
                ELSE 'POSITIVE_WIDER_TOTAL_DOES_NOT_PROVE_ROUTES_FOR_THIS_METHOD' END AS settlement_check_reason,
           CASE WHEN score_eligible = 0 THEN 'ACTIVE_ENTITY_OR_UNIQUE_BOOKING_NOT_VERIFIED'
                WHEN wider_route_count = 0 THEN 'TRAVERSAL_SKIPPED_WITHOUT_SETTLEMENT_ROUTES_SECOND_POINT_TBC'
                ELSE 'VALIDATED_CONFIRMATION_LINK_NOT_IMPLEMENTED' END AS confirmation_check_reason
    FROM BookingFacts f
), ScoredBookings AS (
    SELECT b.*,
           CASE WHEN booking_record_id IS NOT NULL THEN
                CASE WHEN bc14_rhp_status = 'WARNING' THEN 1 ELSE 0 END +
                CASE WHEN bc16_parent_status = 'WARNING' THEN 1 ELSE 0 END +
                CASE WHEN bc12_booking_status = 'WARNING' THEN 1 ELSE 0 END +
                CASE WHEN le13_no_active_contacts = 'WARNING' THEN 1 ELSE 0 END +
                CASE WHEN bc07_no_settlement_routes = 'WARNING' THEN 1 ELSE 0 END END AS confirmed_points,
           CASE WHEN booking_record_id IS NOT NULL THEN 2 +
                CASE WHEN bc14_rhp_status = 'UNKNOWN' THEN 1 ELSE 0 END +
                CASE WHEN bc16_parent_status = 'UNKNOWN' THEN 1 ELSE 0 END +
                CASE WHEN bc12_booking_status = 'UNKNOWN' THEN 1 ELSE 0 END +
                CASE WHEN le13_no_active_contacts = 'UNKNOWN' THEN 1 ELSE 0 END +
                CASE WHEN bc07_no_settlement_routes = 'UNKNOWN' THEN 1 ELSE 0 END END AS unknown_checks
    FROM BookingChecks b
), CompanyTotals AS (
    SELECT le_id, COUNT(booking_record_id) AS active_booking_count,
           COUNT(DISTINCT ultimate_parent_id) AS current_parent_count,
           COUNT(DISTINCT rhp_id) AS current_rhp_count,
           COUNT(DISTINCT CASE WHEN rhp_status IN ('ACTIVE','IN_FORMATION') THEN rhp_id END) AS active_rhp_count,
           COUNT(DISTINCT CASE WHEN rhp_status NOT IN ('ACTIVE','IN_FORMATION') THEN rhp_id END) AS nonactive_rhp_count,
           COUNT(DISTINCT CASE WHEN rhp_status IS NULL THEN rhp_id END) AS unknown_rhp_status_count,
           SUM(CASE WHEN booking_record_id IS NOT NULL AND ultimate_parent_id IS NULL THEN 1 ELSE 0 END) AS unresolved_booking_count,
           SUM(CASE WHEN booking_source_rows > 1 OR system_mapping_rows > 1 THEN 1 ELSE 0 END) AS ambiguous_booking_count,
           SUM(CASE WHEN wider_route_count = 0 THEN 1 ELSE 0 END) AS zero_wider_route_bookings,
           SUM(CASE WHEN confirmed_points > 0 THEN 1 ELSE 0 END) AS bookings_with_warning_points,
           AVG(confirmed_points) AS avg_confirmed_points,
           MIN(confirmed_points) AS min_confirmed_points, MAX(confirmed_points) AS max_confirmed_points
    FROM ScoredBookings GROUP BY le_id
), ParentTotals AS (
    SELECT le_id, ultimate_parent_id, COUNT(*) AS bookings_for_current_parent,
           COUNT(DISTINCT booking_code) AS codes_for_current_parent
    FROM ScoredBookings WHERE booking_record_id IS NOT NULL AND ultimate_parent_id IS NOT NULL
    GROUP BY le_id, ultimate_parent_id
)
SELECT 'flat-booking-review-v1-prototype' AS extract_definition,
       SYSTIMESTAMP AS query_time, cfg.selection_mode,
       COUNT(*) OVER () AS expected_result_rows,
       (SELECT COUNT(*) FROM SelectedEntities) AS selected_company_count,
       CASE WHEN b.entity_source_rows = 0 THEN 'ENTITY_NOT_FOUND'
            WHEN b.entity_source_rows > 1 THEN 'ENTITY_AMBIGUOUS'
            WHEN b.booking_record_id IS NULL THEN 'COMPANY_NO_ACTIVE_BOOKINGS'
            ELSE 'BOOKING' END AS row_kind,
       CAST(b.le_id AS VARCHAR2(128)) AS entity_id, b.company_name, b.company_status,
       b.entity_source_rows, b.booking_source_rows,
       CASE WHEN b.entity_source_rows <> 1 OR ct.ambiguous_booking_count > 0 THEN 'UNKNOWN'
            WHEN UPPER(b.company_status) <> 'ACTIVE' OR b.company_status IS NULL THEN 'NOT_APPLICABLE'
            WHEN ct.current_parent_count > 1 THEN 'MULTIPLE_PARENTS'
            WHEN ct.current_parent_count = 1 THEN 'ONE_PARENT' ELSE 'NO_CURRENT_PARENT' END AS current_parent_rule,
       CASE WHEN b.entity_source_rows = 1 THEN ct.active_booking_count END AS company_active_bookings,
       CASE WHEN b.entity_source_rows = 1 AND ct.ambiguous_booking_count = 0 THEN ct.current_parent_count END AS company_current_parents,
       b.baseline_parent_count AS company_baseline_parents, b.baseline_has_tie,
       ct.current_rhp_count AS company_observed_current_rhps,
       ct.active_rhp_count, ct.nonactive_rhp_count, ct.unknown_rhp_status_count,
       ct.unresolved_booking_count, ct.zero_wider_route_bookings,
       ct.bookings_with_warning_points, ct.avg_confirmed_points, ct.min_confirmed_points, ct.max_confirmed_points,
       CAST(b.booking_record_id AS VARCHAR2(128)) AS booking_record_id,
       b.booking_code, CASE WHEN b.booking_record_id IS NOT NULL THEN 'Active' END AS icms_booking_status,
       CAST(b.settlement_system_id AS VARCHAR2(128)) AS icms_system_id,
       b.system_name, b.crds_system_id, b.system_mapping_rows,
       CAST(b.settlement_method_id AS VARCHAR2(128)) AS settlement_method_id,
       b.method_name AS settlement_method_name, b.method_lookup_rows,
       b.assigned_crds_id, b.activated_db_le_id, b.override_source,
       b.path_resolution, b.full_parent_path_rows, b.full_path_parent_count,
       b.current_parents_on_key, b.key_baseline_tie,
       CAST(b.rhp_id AS VARCHAR2(128)) AS current_rhp_id, b.rhp_name, b.rhp_status, b.rhp_status_date,
       CAST(b.rhp_surviving_party_id AS VARCHAR2(128)) AS rhp_surviving_party_id,
       CAST(b.ultimate_parent_id AS VARCHAR2(128)) AS current_parent_id,
       b.parent_name, b.parent_status, b.parent_status_date,
       pt.bookings_for_current_parent, pt.codes_for_current_parent,
       b.current_xref_status, b.product_system_status, b.product_adoption_status,
       b.adoption_entity_status, b.adoption_location_status, b.relationship_status, b.hierarchy_status,
       b.all_status_path_rows, b.all_status_rhp_count, b.all_status_parent_count,
       CASE WHEN TRIM(b.assigned_crds_id) IS NULL THEN 'MISSING'
            WHEN b.rhp_id IS NULL THEN 'NO_RHP'
            WHEN b.assigned_crds_id = CAST(b.rhp_id AS VARCHAR2(128)) THEN 'SAME_AS_RHP'
            ELSE 'DIFFERS_FROM_RHP' END AS assigned_crds_id_check,
       b.salesforce_rows, b.reporting_group_id, b.reporting_group_name, b.reporting_level, b.sf_legal_parent_id,
       CASE WHEN b.rhp_id IS NULL THEN 'NO_RHP'
            WHEN b.salesforce_rows > 1 THEN 'AMBIGUOUS'
            WHEN b.salesforce_rows = 0 THEN 'NOT_IN_SALESFORCE'
            WHEN b.reporting_group_id IS NULL THEN 'NO_REPORTING_GROUP'
            WHEN b.reporting_group_id = CAST(b.ultimate_parent_id AS VARCHAR2(128)) THEN 'SAME_AS_ULTIMATE'
            WHEN b.reporting_group_id = CAST(b.rhp_id AS VARCHAR2(128)) THEN 'SAME_AS_RHP'
            ELSE 'DIFFERENT_IDS' END AS reporting_group_id_check,
       'NOT_EVALUATED' AS reporting_group_name_check,
       b.shared_key_other_entities, b.active_contact_count, b.contact_count_status,
       b.wider_route_count, 'ENTITY_CODE_ICMS_SYSTEM' AS routing_count_scope,
       b.blocked_account_route_count, b.routed_account_count,
       b.missing_account_route_count, b.other_owner_route_count, b.last_routing_change,
       b.platform_link_rows, b.platform_record_count, b.verified_named_records,
       b.key_only_named_records, b.platform_conflict_records,
       b.verified_name_count, b.unique_verified_name, b.unique_verified_platform,
       b.verified_firm_name_count, b.unique_verified_firm_name,
       b.rhp_observed_lei, b.rhp_lei_value_count, b.parent_observed_lei, b.parent_lei_value_count,
       'OBSERVATIONS_NOT_VALIDATED_IDENTITY' AS lei_evidence_status,
       b.bc14_rhp_status, b.bc16_parent_status, b.bc12_booking_status, b.le13_no_active_contacts,
       b.bc07_no_settlement_routes, b.bc10_no_confirmation_routes, b.bc21_no_recent_trades,
       CASE WHEN b.score_eligible = 0 THEN 'ACTIVE_ENTITY_OR_UNIQUE_BOOKING_NOT_VERIFIED'
            WHEN b.rhp_warning IS NULL OR b.parent_warning IS NULL OR b.booking_warning IS NULL
            THEN 'MISSING_UNRECOGNIZED_OR_CONFLICTING_PATH_STATUS'
            ELSE 'ALL_OBSERVED_PATHS_AGREE_ON_EACH_STATUS_CHECK' END AS status_check_reason,
       b.settlement_check_reason, b.confirmation_check_reason,
       'VALIDATED_DATED_TRADE_LINK_NOT_IMPLEMENTED' AS trading_check_reason,
       b.confirmed_points, b.unknown_checks,
       CAST(NULL AS NUMBER) AS unused_score,
       CASE WHEN b.booking_record_id IS NULL THEN 'NOT_APPLICABLE' ELSE 'INCOMPLETE' END AS score_coverage,
       NVL(b.party_matrix_candidates, 'UNKNOWN') AS matrix_party_candidates,
       CASE WHEN b.booking_warning = 0 THEN 'NO_SIGNAL'
            WHEN b.booking_warning = 1 THEN 'ROWS_5_6' ELSE 'UNKNOWN' END AS matrix_booking_candidates,
       CASE WHEN b.wider_route_count = 0 THEN 'ROWS_7_8' ELSE 'UNKNOWN' END AS matrix_routing_candidates,
       'UNKNOWN' AS matrix_final_confidence,
       'NOT_RUN' AS ai_status,
       'FULL_CLIENT_FETCH_REQUIRED' AS export_completeness
FROM ScoredBookings b
JOIN CompanyTotals ct ON ct.le_id = b.le_id
LEFT JOIN ParentTotals pt ON pt.le_id = b.le_id AND pt.ultimate_parent_id = b.ultimate_parent_id
CROSS JOIN Parameters cfg
ORDER BY b.le_id, b.booking_record_id
