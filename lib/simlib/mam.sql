------------------------------------------------------------------------
-- FILE: mam.sql
--
-- SQL Schema for the mam(n) module.
--
-- PACKAGE:
--    simlib(n) -- Simulation Infrastructure Package
--
-- PROJECT:
--    Mars Simulation Infrastructure Library
--
-- AUTHOR:
--    Will Duquette
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Inputs

-- mam(n) Entities table.  An entity is a collection of people that
-- can have beliefs about topics.
--
-- Entities are identified simply by a brief mnemonic, because it is
-- expected that every entity will be more fully described by the client.

CREATE TABLE mam_entity (
    eid       TEXT PRIMARY KEY     -- A brief mnemonic ID for this topic.
);

-- mam(n) Topics table.  A topic is something about which
-- an entity may have a belief.

CREATE TABLE mam_topic (
    tid       TEXT PRIMARY KEY,    -- A brief mnemonic ID for this topic

    -- A human-readable string describing the topic in more detail
    title TEXT DEFAULT 'TBD'
        CHECK (title != ''),

     -- Relevance of this topic in the region.
    relevance INTEGER DEFAULT 1  
        CHECK (relevance IN (0, 1))
);

-- mam(n) Beliefs table.  A belief is a position taken by an entity
-- with respect to some topic.

CREATE TABLE mam_belief (
    -- Foreign Keys
    eid       TEXT REFERENCES mam_entity(eid)
                   ON DELETE CASCADE ON UPDATE CASCADE
                   DEFERRABLE INITIALLY DEFERRED,
    tid       TEXT REFERENCES mam_topic(tid)
                   ON DELETE CASCADE ON UPDATE CASCADE
                   DEFERRABLE INITIALLY DEFERRED,

    -- The entity's position on this topic, i.e., the extent to which
    -- this topic moves the entity to action.  -1.0 to 1.0
    position  REAL DEFAULT 0.0
        CHECK (-1.0 <= position AND position <= 1.0),

    -- The entity's tolerance for disagreement on this topic.
    -- 0.5 is balanced, neither particularly tolerant nor particularly
    -- intolerant.
    tolerance REAL DEFAULT 0.5
        CHECK (0.0 <= tolerance AND tolerance <= 1.0),

    PRIMARY KEY (eid, tid)
);

------------------------------------------------------------------------
-- Undo

-- mam(n) Undo stack table.  Operations are undone in reverse order.
-- The script is a Tcl script that undoes the operation.

CREATE TABLE mam_undo (
    id     INTEGER PRIMARY KEY,
    script TEXT
);

------------------------------------------------------------------------
-- Outputs

-- mam(n) Affinity Table.  Contains the affinity of each entity with
-- every other entity.  Note that entities are not necessarily symmetric.

CREATE TABLE mam_affinity (
    -- Foreign Keys
    e TEXT REFERENCES mam_entity(eid)
           ON DELETE CASCADE ON UPDATE CASCADE
           DEFERRABLE INITIALLY DEFERRED,
    f TEXT REFERENCES mam_entity(eid)
           ON DELETE CASCADE ON UPDATE CASCADE
           DEFERRABLE INITIALLY DEFERRED,

    -- Affinity of e for f.
    affinity REAL DEFAULT 0.0
        CHECK (-1.0 <= affinity AND affinity <= 1.0),

    PRIMARY KEY (e, f)
);

------------------------------------------------------------------------
-- GUI Views

-- mam(n) belief view.  Creates an "id" column to use as the UID in
-- sqlbrowser(n).

CREATE VIEW mam_belief_view AS
SELECT eid || ' ' || tid AS id,
       eid,
       tid,
       position,
       tolerance
FROM mam_belief; 

-- mam(n) affinity comparison view: compares a group's affinities with
-- other groups with their affinities for it.

CREATE VIEW mam_acompare_view AS
   SELECT A1.e || ' ' || A1.f         AS id,
          A1.e                        AS e,
          A1.f                        AS f,
          format("%5.2f",A1.affinity) AS aef,
          format("%5.2f",A2.affinity) AS afe
   FROM mam_affinity AS A1
   JOIN mam_affinity AS A2 ON (A2.e=A1.f AND A2.f=A1.e);