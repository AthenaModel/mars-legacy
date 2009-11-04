------------------------------------------------------------------------
-- TITLE:
--    gui_views.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views
--
--    These views translate internal data formats into presentation format.
--    
------------------------------------------------------------------------

-- gv_gram_sat
CREATE TEMPORARY VIEW gv_gram_sat AS
SELECT ngc_id,
       ng_id,
       n, 
       g, 
       c,
       gtype,
       saliency,
       trend,
       curve_id, 
       format('%.3f',sat0)  AS sat0, 
       format('%.3f',sat)   AS sat, 
       format('%.3f',delta) AS delta,
       format('%.3f',slope) AS slope
FROM gram_sat;

-- gv_gram_coop
CREATE TEMPORARY VIEW gv_gram_coop AS
SELECT nfg_id,
       curve_id,
       n,
       f,
       g,
       format('%.3f', coop0) AS coop0,
       format('%.3f', coop)  AS coop,
       format('%.3f', delta) AS delta,
       format('%.3f', slope) AS slope
FROM gram_coop;
