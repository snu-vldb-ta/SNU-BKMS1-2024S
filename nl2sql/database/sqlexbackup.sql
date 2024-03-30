--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.16
-- Dumped by pg_dump version 9.5.12

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: box2d; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.box2d;


ALTER TYPE public.box2d OWNER TO postgres;

--
-- Name: box2df; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.box2df;


ALTER TYPE public.box2df OWNER TO postgres;

--
-- Name: box3d; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.box3d;


ALTER TYPE public.box3d OWNER TO postgres;

--
-- Name: geography; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.geography;


ALTER TYPE public.geography OWNER TO postgres;

--
-- Name: geometry; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.geometry;


ALTER TYPE public.geometry OWNER TO postgres;

--
-- Name: gidx; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.gidx;


ALTER TYPE public.gidx OWNER TO postgres;

--
-- Name: histogram; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.histogram AS (
	min double precision,
	max double precision,
	count bigint,
	percent double precision
);


ALTER TYPE public.histogram OWNER TO postgres;

--
-- Name: TYPE histogram; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TYPE public.histogram IS 'postgis raster type: A composite type used as record output of the ST_Histogram and ST_ApproxHistogram functions.';


--
-- Name: pgis_abs; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.pgis_abs;


ALTER TYPE public.pgis_abs OWNER TO postgres;

--
-- Name: quantile; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.quantile AS (
	quantile double precision,
	value double precision
);


ALTER TYPE public.quantile OWNER TO postgres;

--
-- Name: raster; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.raster;


ALTER TYPE public.raster OWNER TO postgres;

--
-- Name: TYPE raster; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TYPE public.raster IS 'postgis raster type: raster spatial data type.';


--
-- Name: reclassarg; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.reclassarg AS (
	nband integer,
	reclassexpr text,
	pixeltype text,
	nodataval double precision
);


ALTER TYPE public.reclassarg OWNER TO postgres;

--
-- Name: TYPE reclassarg; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TYPE public.reclassarg IS 'postgis raster type: A composite type used as input into the ST_Reclass function defining the behavior of reclassification.';


--
-- Name: spheroid; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.spheroid;


ALTER TYPE public.spheroid OWNER TO postgres;

--
-- Name: summarystats; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.summarystats AS (
	count bigint,
	sum double precision,
	mean double precision,
	stddev double precision,
	min double precision,
	max double precision
);


ALTER TYPE public.summarystats OWNER TO postgres;

--
-- Name: TYPE summarystats; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TYPE public.summarystats IS 'postgis raster type: A composite type used as output of the ST_SummaryStats function.';


--
-- Name: valuecount; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.valuecount AS (
	value double precision,
	count integer,
	percent double precision
);


ALTER TYPE public.valuecount OWNER TO postgres;

--
-- Name: _add_overview_constraint(name, name, name, name, name, name, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_overview_constraint(ovschema name, ovtable name, ovcolumn name, refschema name, reftable name, refcolumn name, factor integer) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_overview_' || $3;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (_overview_constraint(' || quote_ident($3)
			|| ',' || $7
			|| ',' || quote_literal($4)
			|| ',' || quote_literal($5)
			|| ',' || quote_literal($6)
			|| '))';

		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_overview_constraint(ovschema name, ovtable name, ovcolumn name, refschema name, reftable name, refcolumn name, factor integer) OWNER TO postgres;

--
-- Name: _add_raster_constraint(name, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint(cn name, sql text) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $$
	BEGIN
		BEGIN
			EXECUTE sql;
		EXCEPTION
			WHEN duplicate_object THEN
				RAISE NOTICE 'The constraint "%" already exists.  To replace the existing constraint, delete the constraint and call ApplyRasterConstraints again', cn;
			WHEN OTHERS THEN
				RAISE NOTICE 'Unable to add constraint "%"', cn;
				RETURN FALSE;
		END;

		RETURN TRUE;
	END;
	$$;


ALTER FUNCTION public._add_raster_constraint(cn name, sql text) OWNER TO postgres;

--
-- Name: _add_raster_constraint_alignment(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_alignment(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_same_alignment_' || $3;

		sql := 'SELECT st_makeemptyraster(1, 1, upperleftx, upperlefty, scalex, scaley, skewx, skewy, srid) FROM st_metadata((SELECT '
			|| quote_ident($3)
			|| ' FROM ' || fqtn || ' LIMIT 1))';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the alignment of a sample raster';
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn ||
			' ADD CONSTRAINT ' || quote_ident(cn) ||
			' CHECK (st_samealignment(' || quote_ident($3) || ', ''' || attr || '''::raster))';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_alignment(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_blocksize(name, name, name, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_blocksize(rastschema name, rasttable name, rastcolumn name, axis text) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr int;
	BEGIN
		IF lower($4) != 'width' AND lower($4) != 'height' THEN
			RAISE EXCEPTION 'axis must be either "width" or "height"';
			RETURN FALSE;
		END IF;

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_' || $4 || '_' || $3;

		sql := 'SELECT st_' || $4 || '('
			|| quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the % of a sample raster', $4;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (st_' || $4 || '('
			|| quote_ident($3)
			|| ') = ' || attr || ')';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_blocksize(rastschema name, rasttable name, rastcolumn name, axis text) OWNER TO postgres;

--
-- Name: _add_raster_constraint_extent(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_extent(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_max_extent_' || $3;

		sql := 'SELECT st_ashexewkb(st_convexhull(st_collect(st_convexhull('
			|| quote_ident($3)
			|| ')))) FROM '
			|| fqtn;
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the extent of a sample raster';
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (st_coveredby(st_convexhull('
			|| quote_ident($3)
			|| '), ''' || attr || '''::geometry))';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_extent(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_nodata_values(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_nodata_values(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr double precision[];
		max int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_nodata_values_' || $3;

		sql := 'SELECT _raster_constraint_nodata_values(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the nodata values of a sample raster';
			RETURN FALSE;
		END;
		max := array_length(attr, 1);
		IF max < 1 OR max IS NULL THEN
			RAISE NOTICE 'Unable to get the nodata values of a sample raster';
			RETURN FALSE;
		END IF;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (_raster_constraint_nodata_values(' || quote_ident($3)
			|| ')::numeric(16,10)[] = ''{';
		FOR x in 1..max LOOP
			IF attr[x] IS NULL THEN
				sql := sql || 'NULL';
			ELSE
				sql := sql || attr[x];
			END IF;
			IF x < max THEN
				sql := sql || ',';
			END IF;
		END LOOP;
		sql := sql || '}''::numeric(16,10)[])';

		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_nodata_values(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_num_bands(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_num_bands(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_num_bands_' || $3;

		sql := 'SELECT st_numbands(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the number of bands of a sample raster';
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (st_numbands(' || quote_ident($3)
			|| ') = ' || attr
			|| ')';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_num_bands(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_out_db(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_out_db(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr boolean[];
		max int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_out_db_' || $3;

		sql := 'SELECT _raster_constraint_out_db(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the out-of-database bands of a sample raster';
			RETURN FALSE;
		END;
		max := array_length(attr, 1);
		IF max < 1 OR max IS NULL THEN
			RAISE NOTICE 'Unable to get the out-of-database bands of a sample raster';
			RETURN FALSE;
		END IF;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (_raster_constraint_out_db(' || quote_ident($3)
			|| ') = ''{';
		FOR x in 1..max LOOP
			IF attr[x] IS FALSE THEN
				sql := sql || 'FALSE';
			ELSE
				sql := sql || 'TRUE';
			END IF;
			IF x < max THEN
				sql := sql || ',';
			END IF;
		END LOOP;
		sql := sql || '}''::boolean[])';

		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_out_db(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_pixel_types(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_pixel_types(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text[];
		max int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_pixel_types_' || $3;

		sql := 'SELECT _raster_constraint_pixel_types(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the pixel types of a sample raster';
			RETURN FALSE;
		END;
		max := array_length(attr, 1);
		IF max < 1 OR max IS NULL THEN
			RAISE NOTICE 'Unable to get the pixel types of a sample raster';
			RETURN FALSE;
		END IF;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (_raster_constraint_pixel_types(' || quote_ident($3)
			|| ') = ''{';
		FOR x in 1..max LOOP
			sql := sql || '"' || attr[x] || '"';
			IF x < max THEN
				sql := sql || ',';
			END IF;
		END LOOP;
		sql := sql || '}''::text[])';

		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_pixel_types(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_regular_blocking(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
	BEGIN

		RAISE INFO 'The regular_blocking constraint is just a flag indicating that the column "%" is regularly blocked.  It is up to the end-user to ensure that the column is truely regularly blocked.', quote_ident($3);

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_regular_blocking_' || $3;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (TRUE)';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _add_raster_constraint_scale(name, name, name, character); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_scale(rastschema name, rasttable name, rastcolumn name, axis character) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr double precision;
	BEGIN
		IF lower($4) != 'x' AND lower($4) != 'y' THEN
			RAISE EXCEPTION 'axis must be either "x" or "y"';
			RETURN FALSE;
		END IF;

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_scale' || $4 || '_' || $3;

		sql := 'SELECT st_scale' || $4 || '('
			|| quote_ident($3)
			|| ') FROM '
			|| fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the %-scale of a sample raster', upper($4);
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (st_scale' || $4 || '('
			|| quote_ident($3)
			|| ')::numeric(16,10) = (' || attr || ')::numeric(16,10))';
		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_scale(rastschema name, rasttable name, rastcolumn name, axis character) OWNER TO postgres;

--
-- Name: _add_raster_constraint_srid(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._add_raster_constraint_srid(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_srid_' || $3;

		sql := 'SELECT st_srid('
			|| quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' LIMIT 1';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the SRID of a sample raster';
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (st_srid('
			|| quote_ident($3)
			|| ') = ' || attr || ')';

		RETURN _add_raster_constraint(cn, sql);
	END;
	$_$;


ALTER FUNCTION public._add_raster_constraint_srid(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_overview_constraint(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_overview_constraint(ovschema name, ovtable name, ovcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_overview_' || $3) $_$;


ALTER FUNCTION public._drop_overview_constraint(ovschema name, ovtable name, ovcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint(rastschema name, rasttable name, cn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		fqtn text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		BEGIN
			EXECUTE 'ALTER TABLE '
				|| fqtn
				|| ' DROP CONSTRAINT '
				|| quote_ident(cn);
			RETURN TRUE;
		EXCEPTION
			WHEN undefined_object THEN
				RAISE NOTICE 'The constraint "%" does not exist.  Skipping', cn;
			WHEN OTHERS THEN
				RAISE NOTICE 'Unable to drop constraint "%"', cn;
				RETURN FALSE;
		END;

		RETURN TRUE;
	END;
	$_$;


ALTER FUNCTION public._drop_raster_constraint(rastschema name, rasttable name, cn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_alignment(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_alignment(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_same_alignment_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_alignment(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_blocksize(name, name, name, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_blocksize(rastschema name, rasttable name, rastcolumn name, axis text) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	BEGIN
		IF lower($4) != 'width' AND lower($4) != 'height' THEN
			RAISE EXCEPTION 'axis must be either "width" or "height"';
			RETURN FALSE;
		END IF;

		RETURN _drop_raster_constraint($1, $2, 'enforce_' || $4 || '_' || $3);
	END;
	$_$;


ALTER FUNCTION public._drop_raster_constraint_blocksize(rastschema name, rasttable name, rastcolumn name, axis text) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_extent(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_extent(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_max_extent_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_extent(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_nodata_values(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_nodata_values(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_nodata_values_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_nodata_values(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_num_bands(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_num_bands(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_num_bands_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_num_bands(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_out_db(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_out_db(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_out_db_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_out_db(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_pixel_types(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_pixel_types(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_pixel_types_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_pixel_types(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_regular_blocking(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_regular_blocking_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_scale(name, name, name, character); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_scale(rastschema name, rasttable name, rastcolumn name, axis character) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	BEGIN
		IF lower($4) != 'x' AND lower($4) != 'y' THEN
			RAISE EXCEPTION 'axis must be either "x" or "y"';
			RETURN FALSE;
		END IF;

		RETURN _drop_raster_constraint($1, $2, 'enforce_scale' || $4 || '_' || $3);
	END;
	$_$;


ALTER FUNCTION public._drop_raster_constraint_scale(rastschema name, rasttable name, rastcolumn name, axis character) OWNER TO postgres;

--
-- Name: _drop_raster_constraint_srid(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._drop_raster_constraint_srid(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT _drop_raster_constraint($1, $2, 'enforce_srid_' || $3) $_$;


ALTER FUNCTION public._drop_raster_constraint_srid(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _overview_constraint_info(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._overview_constraint_info(ovschema name, ovtable name, ovcolumn name, OUT refschema name, OUT reftable name, OUT refcolumn name, OUT factor integer) RETURNS record
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		split_part(split_part(s.consrc, '''::name', 1), '''', 2)::name,
		split_part(split_part(s.consrc, '''::name', 2), '''', 2)::name,
		split_part(split_part(s.consrc, '''::name', 3), '''', 2)::name,
		trim(both from split_part(s.consrc, ',', 2))::integer
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_overview_constraint(%'
	$_$;


ALTER FUNCTION public._overview_constraint_info(ovschema name, ovtable name, ovcolumn name, OUT refschema name, OUT reftable name, OUT refcolumn name, OUT factor integer) OWNER TO postgres;

--
-- Name: _raster_constraint_info_alignment(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_alignment(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		TRUE
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_samealignment(%';
	$_$;


ALTER FUNCTION public._raster_constraint_info_alignment(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _raster_constraint_info_blocksize(name, name, name, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_blocksize(rastschema name, rasttable name, rastcolumn name, axis text) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', '')::integer
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_' || $4 || '(% = %';
	$_$;


ALTER FUNCTION public._raster_constraint_info_blocksize(rastschema name, rasttable name, rastcolumn name, axis text) OWNER TO postgres;

--
-- Name: _raster_constraint_info_nodata_values(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_nodata_values(rastschema name, rasttable name, rastcolumn name) RETURNS double precision[]
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		trim(both '''' from split_part(replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', ''), '::', 1))::double precision[]
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_raster_constraint_nodata_values(%';
	$_$;


ALTER FUNCTION public._raster_constraint_info_nodata_values(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _raster_constraint_info_num_bands(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_num_bands(rastschema name, rasttable name, rastcolumn name) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', '')::integer
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_numbands(%';
	$_$;


ALTER FUNCTION public._raster_constraint_info_num_bands(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _raster_constraint_info_out_db(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_out_db(rastschema name, rasttable name, rastcolumn name) RETURNS boolean[]
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		trim(both '''' from split_part(replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', ''), '::', 1))::boolean[]
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_raster_constraint_out_db(%';
	$_$;


ALTER FUNCTION public._raster_constraint_info_out_db(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _raster_constraint_info_pixel_types(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_pixel_types(rastschema name, rasttable name, rastcolumn name) RETURNS text[]
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		trim(both '''' from split_part(replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', ''), '::', 1))::text[]
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_raster_constraint_pixel_types(%';
	$_$;


ALTER FUNCTION public._raster_constraint_info_pixel_types(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _raster_constraint_info_regular_blocking(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_regular_blocking(rastschema name, rasttable name, rastcolumn name) RETURNS boolean
    LANGUAGE plpgsql STABLE STRICT
    AS $_$
	DECLARE
		cn text;
		sql text;
		rtn boolean;
	BEGIN
		cn := 'enforce_regular_blocking_' || $3;

		sql := 'SELECT TRUE FROM pg_class c, pg_namespace n, pg_constraint s'
			|| ' WHERE n.nspname = ' || quote_literal($1)
			|| ' AND c.relname = ' || quote_literal($2)
			|| ' AND s.connamespace = n.oid AND s.conrelid = c.oid'
			|| ' AND s.conname = ' || quote_literal(cn);
		EXECUTE sql INTO rtn;
		RETURN rtn;
	END;
	$_$;


ALTER FUNCTION public._raster_constraint_info_regular_blocking(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _raster_constraint_info_scale(name, name, name, character); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_scale(rastschema name, rasttable name, rastcolumn name, axis character) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		replace(replace(split_part(split_part(s.consrc, ' = ', 2), '::', 1), ')', ''), '(', '')::double precision
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_scale' || $4 || '(% = %';
	$_$;


ALTER FUNCTION public._raster_constraint_info_scale(rastschema name, rasttable name, rastcolumn name, axis character) OWNER TO postgres;

--
-- Name: _raster_constraint_info_srid(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._raster_constraint_info_srid(rastschema name, rasttable name, rastcolumn name) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$
	SELECT
		replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', '')::integer
	FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_srid(% = %';
	$_$;


ALTER FUNCTION public._raster_constraint_info_srid(rastschema name, rasttable name, rastcolumn name) OWNER TO postgres;

--
-- Name: _st_aspect4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_aspect4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        pwidth float;
        pheight float;
        dz_dx float;
        dz_dy float;
        aspect float;
    BEGIN
        pwidth := args[1]::float;
        pheight := args[2]::float;
        dz_dx := ((matrix[3][1] + 2.0 * matrix[3][2] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[1][2] + matrix[1][3])) / (8.0 * pwidth);
        dz_dy := ((matrix[1][3] + 2.0 * matrix[2][3] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[2][1] + matrix[3][1])) / (8.0 * pheight);
        IF abs(dz_dx) = 0::float AND abs(dz_dy) = 0::float THEN
            RETURN -1;
        END IF;

        aspect := atan2(dz_dy, -dz_dx);
        IF aspect > (pi() / 2.0) THEN
            RETURN (5.0 * pi() / 2.0) - aspect;
        ELSE
            RETURN (pi() / 2.0) - aspect;
        END IF;
    END;
    $$;


ALTER FUNCTION public._st_aspect4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: _st_count(text, text, integer, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_count(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, sample_percent double precision DEFAULT 1) RETURNS bigint
    LANGUAGE plpgsql STABLE STRICT
    AS $_$
	DECLARE
		curs refcursor;

		ctable text;
		ccolumn text;
		rast raster;
		stats summarystats;

		rtn bigint;
		tmp bigint;
	BEGIN
		-- nband
		IF nband < 1 THEN
			RAISE WARNING 'Invalid band index (must use 1-based). Returning NULL';
			RETURN NULL;
		END IF;

		-- sample percent
		IF sample_percent < 0 OR sample_percent > 1 THEN
			RAISE WARNING 'Invalid sample percentage (must be between 0 and 1). Returning NULL';
			RETURN NULL;
		END IF;

		-- exclude_nodata_value IS TRUE
		IF exclude_nodata_value IS TRUE THEN
			SELECT count INTO rtn FROM _st_summarystats($1, $2, $3, $4, $5);
			RETURN rtn;
		END IF;

		-- clean rastertable and rastercolumn
		ctable := quote_ident(rastertable);
		ccolumn := quote_ident(rastercolumn);

		BEGIN
			OPEN curs FOR EXECUTE 'SELECT '
					|| ccolumn
					|| ' FROM '
					|| ctable
					|| ' WHERE '
					|| ccolumn
					|| ' IS NOT NULL';
		EXCEPTION
			WHEN OTHERS THEN
				RAISE WARNING 'Invalid table or column name. Returning NULL';
				RETURN NULL;
		END;

		rtn := 0;
		LOOP
			FETCH curs INTO rast;
			EXIT WHEN NOT FOUND;

			SELECT (width * height) INTO tmp FROM ST_Metadata(rast);
			rtn := rtn + tmp;
		END LOOP;

		CLOSE curs;

		RETURN rtn;
	END;
	$_$;


ALTER FUNCTION public._st_count(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision) OWNER TO postgres;

--
-- Name: _st_hillshade4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_hillshade4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        pwidth float;
        pheight float;
        dz_dx float;
        dz_dy float;
        zenith float;
        azimuth float;
        slope float;
        aspect float;
        max_bright float;
        elevation_scale float;
    BEGIN
        pwidth := args[1]::float;
        pheight := args[2]::float;
        azimuth := (5.0 * pi() / 2.0) - args[3]::float;
        zenith := (pi() / 2.0) - args[4]::float;
        dz_dx := ((matrix[3][1] + 2.0 * matrix[3][2] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[1][2] + matrix[1][3])) / (8.0 * pwidth);
        dz_dy := ((matrix[1][3] + 2.0 * matrix[2][3] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[2][1] + matrix[3][1])) / (8.0 * pheight);
        elevation_scale := args[6]::float;
        slope := atan(sqrt(elevation_scale * pow(dz_dx, 2.0) + pow(dz_dy, 2.0)));
        -- handle special case of 0, 0
        IF abs(dz_dy) = 0::float AND abs(dz_dy) = 0::float THEN
            -- set to pi as that is the expected PostgreSQL answer in Linux
            aspect := pi();
        ELSE
            aspect := atan2(dz_dy, -dz_dx);
        END IF;
        max_bright := args[5]::float;

        IF aspect < 0 THEN
            aspect := aspect + (2.0 * pi());
        END IF;

        RETURN max_bright * ( (cos(zenith)*cos(slope)) + (sin(zenith)*sin(slope)*cos(azimuth - aspect)) );
    END;
    $$;


ALTER FUNCTION public._st_hillshade4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: _st_slope4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._st_slope4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        pwidth float;
        pheight float;
        dz_dx float;
        dz_dy float;
    BEGIN
        pwidth := args[1]::float;
        pheight := args[2]::float;
        dz_dx := ((matrix[3][1] + 2.0 * matrix[3][2] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[1][2] + matrix[1][3])) / (8.0 * pwidth);
        dz_dy := ((matrix[1][3] + 2.0 * matrix[2][3] + matrix[3][3]) - (matrix[1][1] + 2.0 * matrix[2][1] + matrix[3][1])) / (8.0 * pheight);
        RETURN atan(sqrt(pow(dz_dx, 2.0) + pow(dz_dy, 2.0)));
    END;
    $$;


ALTER FUNCTION public._st_slope4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: addauth(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addauth(text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$ 
DECLARE
	lockid alias for $1;
	okay boolean;
	myrec record;
BEGIN
	-- check to see if table exists
	--  if not, CREATE TEMP TABLE mylock (transid xid, lockcode text)
	okay := 'f';
	FOR myrec IN SELECT * FROM pg_class WHERE relname = 'temp_lock_have_table' LOOP
		okay := 't';
	END LOOP; 
	IF (okay <> 't') THEN 
		CREATE TEMP TABLE temp_lock_have_table (transid xid, lockcode text);
			-- this will only work from pgsql7.4 up
			-- ON COMMIT DELETE ROWS;
	END IF;

	--  INSERT INTO mylock VALUES ( $1)
--	EXECUTE 'INSERT INTO temp_lock_have_table VALUES ( '||
--		quote_literal(getTransactionID()) || ',' ||
--		quote_literal(lockid) ||')';

	INSERT INTO temp_lock_have_table VALUES (getTransactionID(), lockid);

	RETURN true::boolean;
END;
$_$;


ALTER FUNCTION public.addauth(text) OWNER TO postgres;

--
-- Name: addgeometrycolumn(character varying, character varying, integer, character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addgeometrycolumn(table_name character varying, column_name character varying, new_srid integer, new_type character varying, new_dim integer, use_typmod boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
	ret  text;
BEGIN
	SELECT AddGeometryColumn('','',$1,$2,$3,$4,$5, $6) into ret;
	RETURN ret;
END;
$_$;


ALTER FUNCTION public.addgeometrycolumn(table_name character varying, column_name character varying, new_srid integer, new_type character varying, new_dim integer, use_typmod boolean) OWNER TO postgres;

--
-- Name: addgeometrycolumn(character varying, character varying, character varying, integer, character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addgeometrycolumn(schema_name character varying, table_name character varying, column_name character varying, new_srid integer, new_type character varying, new_dim integer, use_typmod boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql STABLE STRICT
    AS $_$
DECLARE
	ret  text;
BEGIN
	SELECT AddGeometryColumn('',$1,$2,$3,$4,$5,$6,$7) into ret;
	RETURN ret;
END;
$_$;


ALTER FUNCTION public.addgeometrycolumn(schema_name character varying, table_name character varying, column_name character varying, new_srid integer, new_type character varying, new_dim integer, use_typmod boolean) OWNER TO postgres;

--
-- Name: addgeometrycolumn(character varying, character varying, character varying, character varying, integer, character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addgeometrycolumn(catalog_name character varying, schema_name character varying, table_name character varying, column_name character varying, new_srid_in integer, new_type character varying, new_dim integer, use_typmod boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
	rec RECORD;
	sr varchar;
	real_schema name;
	sql text;
	new_srid integer;

BEGIN

	-- Verify geometry type
	IF (postgis_type_name(new_type,new_dim) IS NULL )
	THEN
		RAISE EXCEPTION 'Invalid type name "%(%)" - valid ones are:
	POINT, MULTIPOINT,
	LINESTRING, MULTILINESTRING,
	POLYGON, MULTIPOLYGON,
	CIRCULARSTRING, COMPOUNDCURVE, MULTICURVE,
	CURVEPOLYGON, MULTISURFACE,
	GEOMETRY, GEOMETRYCOLLECTION,
	POINTM, MULTIPOINTM,
	LINESTRINGM, MULTILINESTRINGM,
	POLYGONM, MULTIPOLYGONM,
	CIRCULARSTRINGM, COMPOUNDCURVEM, MULTICURVEM
	CURVEPOLYGONM, MULTISURFACEM, TRIANGLE, TRIANGLEM,
	POLYHEDRALSURFACE, POLYHEDRALSURFACEM, TIN, TINM
	or GEOMETRYCOLLECTIONM', new_type, new_dim;
		RETURN 'fail';
	END IF;


	-- Verify dimension
	IF ( (new_dim >4) OR (new_dim <2) ) THEN
		RAISE EXCEPTION 'invalid dimension';
		RETURN 'fail';
	END IF;

	IF ( (new_type LIKE '%M') AND (new_dim!=3) ) THEN
		RAISE EXCEPTION 'TypeM needs 3 dimensions';
		RETURN 'fail';
	END IF;


	-- Verify SRID
	IF ( new_srid_in > 0 ) THEN
		IF new_srid_in > 998999 THEN
			RAISE EXCEPTION 'AddGeometryColumn() - SRID must be <= %', 998999;
		END IF;
		new_srid := new_srid_in;
		SELECT SRID INTO sr FROM spatial_ref_sys WHERE SRID = new_srid;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'AddGeometryColumn() - invalid SRID';
			RETURN 'fail';
		END IF;
	ELSE
		new_srid := ST_SRID('POINT EMPTY'::geometry);
		IF ( new_srid_in != new_srid ) THEN
			RAISE NOTICE 'SRID value % converted to the officially unknown SRID value %', new_srid_in, new_srid;
		END IF;
	END IF;


	-- Verify schema
	IF ( schema_name IS NOT NULL AND schema_name != '' ) THEN
		sql := 'SELECT nspname FROM pg_namespace ' ||
			'WHERE text(nspname) = ' || quote_literal(schema_name) ||
			'LIMIT 1';
		RAISE DEBUG '%', sql;
		EXECUTE sql INTO real_schema;

		IF ( real_schema IS NULL ) THEN
			RAISE EXCEPTION 'Schema % is not a valid schemaname', quote_literal(schema_name);
			RETURN 'fail';
		END IF;
	END IF;

	IF ( real_schema IS NULL ) THEN
		RAISE DEBUG 'Detecting schema';
		sql := 'SELECT n.nspname AS schemaname ' ||
			'FROM pg_catalog.pg_class c ' ||
			  'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace ' ||
			'WHERE c.relkind = ' || quote_literal('r') ||
			' AND n.nspname NOT IN (' || quote_literal('pg_catalog') || ', ' || quote_literal('pg_toast') || ')' ||
			' AND pg_catalog.pg_table_is_visible(c.oid)' ||
			' AND c.relname = ' || quote_literal(table_name);
		RAISE DEBUG '%', sql;
		EXECUTE sql INTO real_schema;

		IF ( real_schema IS NULL ) THEN
			RAISE EXCEPTION 'Table % does not occur in the search_path', quote_literal(table_name);
			RETURN 'fail';
		END IF;
	END IF;


	-- Add geometry column to table
	IF use_typmod THEN
	     sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD COLUMN ' || quote_ident(column_name) ||
            ' geometry(' || postgis_type_name(new_type, new_dim) || ', ' || new_srid::text || ')';
        RAISE DEBUG '%', sql;
	ELSE
        sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD COLUMN ' || quote_ident(column_name) ||
            ' geometry ';
        RAISE DEBUG '%', sql;
    END IF;
	EXECUTE sql;

	IF NOT use_typmod THEN
        -- Add table CHECKs
        sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD CONSTRAINT '
            || quote_ident('enforce_srid_' || column_name)
            || ' CHECK (st_srid(' || quote_ident(column_name) ||
            ') = ' || new_srid::text || ')' ;
        RAISE DEBUG '%', sql;
        EXECUTE sql;
    
        sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD CONSTRAINT '
            || quote_ident('enforce_dims_' || column_name)
            || ' CHECK (st_ndims(' || quote_ident(column_name) ||
            ') = ' || new_dim::text || ')' ;
        RAISE DEBUG '%', sql;
        EXECUTE sql;
    
        IF ( NOT (new_type = 'GEOMETRY')) THEN
            sql := 'ALTER TABLE ' ||
                quote_ident(real_schema) || '.' || quote_ident(table_name) || ' ADD CONSTRAINT ' ||
                quote_ident('enforce_geotype_' || column_name) ||
                ' CHECK (GeometryType(' ||
                quote_ident(column_name) || ')=' ||
                quote_literal(new_type) || ' OR (' ||
                quote_ident(column_name) || ') is null)';
            RAISE DEBUG '%', sql;
            EXECUTE sql;
        END IF;
    END IF;

	RETURN
		real_schema || '.' ||
		table_name || '.' || column_name ||
		' SRID:' || new_srid::text ||
		' TYPE:' || new_type ||
		' DIMS:' || new_dim::text || ' ';
END;
$$;


ALTER FUNCTION public.addgeometrycolumn(catalog_name character varying, schema_name character varying, table_name character varying, column_name character varying, new_srid_in integer, new_type character varying, new_dim integer, use_typmod boolean) OWNER TO postgres;

--
-- Name: addoverviewconstraints(name, name, name, name, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addoverviewconstraints(ovtable name, ovcolumn name, reftable name, refcolumn name, ovfactor integer) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT AddOverviewConstraints('', $1, $2, '', $3, $4, $5) $_$;


ALTER FUNCTION public.addoverviewconstraints(ovtable name, ovcolumn name, reftable name, refcolumn name, ovfactor integer) OWNER TO postgres;

--
-- Name: addoverviewconstraints(name, name, name, name, name, name, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addoverviewconstraints(ovschema name, ovtable name, ovcolumn name, refschema name, reftable name, refcolumn name, ovfactor integer) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		x int;
		s name;
		t name;
		oschema name;
		rschema name;
		sql text;
		rtn boolean;
	BEGIN
		FOR x IN 1..2 LOOP
			s := '';

			IF x = 1 THEN
				s := $1;
				t := $2;
			ELSE
				s := $4;
				t := $5;
			END IF;

			-- validate user-provided schema
			IF length(s) > 0 THEN
				sql := 'SELECT nspname FROM pg_namespace '
					|| 'WHERE nspname = ' || quote_literal(s)
					|| 'LIMIT 1';
				EXECUTE sql INTO s;

				IF s IS NULL THEN
					RAISE EXCEPTION 'The value % is not a valid schema', quote_literal(s);
					RETURN FALSE;
				END IF;
			END IF;

			-- no schema, determine what it could be using the table
			IF length(s) < 1 THEN
				sql := 'SELECT n.nspname AS schemaname '
					|| 'FROM pg_catalog.pg_class c '
					|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
					|| 'WHERE c.relkind = ' || quote_literal('r')
					|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
					|| ', ' || quote_literal('pg_toast')
					|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
					|| ' AND c.relname = ' || quote_literal(t);
				EXECUTE sql INTO s;

				IF s IS NULL THEN
					RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal(t);
					RETURN FALSE;
				END IF;
			END IF;

			IF x = 1 THEN
				oschema := s;
			ELSE
				rschema := s;
			END IF;
		END LOOP;

		-- reference raster
		rtn := _add_overview_constraint(oschema, $2, $3, rschema, $5, $6, $7);
		IF rtn IS FALSE THEN
			RAISE EXCEPTION 'Unable to add the overview constraint.  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$_$;


ALTER FUNCTION public.addoverviewconstraints(ovschema name, ovtable name, ovcolumn name, refschema name, reftable name, refcolumn name, ovfactor integer) OWNER TO postgres;

--
-- Name: addrasterconstraints(name, name, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addrasterconstraints(rasttable name, rastcolumn name, VARIADIC constraints text[]) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT AddRasterConstraints('', $1, $2, VARIADIC $3) $_$;


ALTER FUNCTION public.addrasterconstraints(rasttable name, rastcolumn name, VARIADIC constraints text[]) OWNER TO postgres;

--
-- Name: FUNCTION addrasterconstraints(rasttable name, rastcolumn name, VARIADIC constraints text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.addrasterconstraints(rasttable name, rastcolumn name, VARIADIC constraints text[]) IS 'args: rasttable, rastcolumn, VARIADIC constraints - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true of the constraint setting was accomplished and if issues a notice.';


--
-- Name: addrasterconstraints(name, name, name, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addrasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		max int;
		cnt int;
		sql text;
		schema name;
		x int;
		kw text;
		rtn boolean;
	BEGIN
		cnt := 0;
		max := array_length(constraints, 1);
		IF max < 1 THEN
			RAISE NOTICE 'No constraints indicated to be added.  Doing nothing';
			RETURN TRUE;
		END IF;

		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		<<kwloop>>
		FOR x in 1..max LOOP
			kw := trim(both from lower(constraints[x]));

			BEGIN
				CASE
					WHEN kw = 'srid' THEN
						RAISE NOTICE 'Adding SRID constraint';
						rtn := _add_raster_constraint_srid(schema, $2, $3);
					WHEN kw IN ('scale_x', 'scalex') THEN
						RAISE NOTICE 'Adding scale-X constraint';
						rtn := _add_raster_constraint_scale(schema, $2, $3, 'x');
					WHEN kw IN ('scale_y', 'scaley') THEN
						RAISE NOTICE 'Adding scale-Y constraint';
						rtn := _add_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw = 'scale' THEN
						RAISE NOTICE 'Adding scale-X constraint';
						rtn := _add_raster_constraint_scale(schema, $2, $3, 'x');
						RAISE NOTICE 'Adding scale-Y constraint';
						rtn := _add_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw IN ('blocksize_x', 'blocksizex', 'width') THEN
						RAISE NOTICE 'Adding blocksize-X constraint';
						rtn := _add_raster_constraint_blocksize(schema, $2, $3, 'width');
					WHEN kw IN ('blocksize_y', 'blocksizey', 'height') THEN
						RAISE NOTICE 'Adding blocksize-Y constraint';
						rtn := _add_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw = 'blocksize' THEN
						RAISE NOTICE 'Adding blocksize-X constraint';
						rtn := _add_raster_constraint_blocksize(schema, $2, $3, 'width');
						RAISE NOTICE 'Adding blocksize-Y constraint';
						rtn := _add_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw IN ('same_alignment', 'samealignment', 'alignment') THEN
						RAISE NOTICE 'Adding alignment constraint';
						rtn := _add_raster_constraint_alignment(schema, $2, $3);
					WHEN kw IN ('regular_blocking', 'regularblocking') THEN
						RAISE NOTICE 'Adding regular blocking constraint';
						rtn := _add_raster_constraint_regular_blocking(schema, $2, $3);
					WHEN kw IN ('num_bands', 'numbands') THEN
						RAISE NOTICE 'Adding number of bands constraint';
						rtn := _add_raster_constraint_num_bands(schema, $2, $3);
					WHEN kw IN ('pixel_types', 'pixeltypes') THEN
						RAISE NOTICE 'Adding pixel type constraint';
						rtn := _add_raster_constraint_pixel_types(schema, $2, $3);
					WHEN kw IN ('nodata_values', 'nodatavalues', 'nodata') THEN
						RAISE NOTICE 'Adding nodata value constraint';
						rtn := _add_raster_constraint_nodata_values(schema, $2, $3);
					WHEN kw IN ('out_db', 'outdb') THEN
						RAISE NOTICE 'Adding out-of-database constraint';
						rtn := _add_raster_constraint_out_db(schema, $2, $3);
					WHEN kw = 'extent' THEN
						RAISE NOTICE 'Adding maximum extent constraint';
						rtn := _add_raster_constraint_extent(schema, $2, $3);
					ELSE
						RAISE NOTICE 'Unknown constraint: %.  Skipping', quote_literal(constraints[x]);
						CONTINUE kwloop;
				END CASE;
			END;

			IF rtn IS FALSE THEN
				cnt := cnt + 1;
				RAISE WARNING 'Unable to add constraint: %.  Skipping', quote_literal(constraints[x]);
			END IF;

		END LOOP kwloop;

		IF cnt = max THEN
			RAISE EXCEPTION 'None of the constraints specified could be added.  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$_$;


ALTER FUNCTION public.addrasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]) OWNER TO postgres;

--
-- Name: FUNCTION addrasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.addrasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]) IS 'args: rastschema, rasttable, rastcolumn, VARIADIC constraints - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true of the constraint setting was accomplished and if issues a notice.';


--
-- Name: addrasterconstraints(name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addrasterconstraints(rasttable name, rastcolumn name, srid boolean DEFAULT true, scale_x boolean DEFAULT true, scale_y boolean DEFAULT true, blocksize_x boolean DEFAULT true, blocksize_y boolean DEFAULT true, same_alignment boolean DEFAULT true, regular_blocking boolean DEFAULT false, num_bands boolean DEFAULT true, pixel_types boolean DEFAULT true, nodata_values boolean DEFAULT true, out_db boolean DEFAULT true, extent boolean DEFAULT true) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT AddRasterConstraints('', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) $_$;


ALTER FUNCTION public.addrasterconstraints(rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) OWNER TO postgres;

--
-- Name: FUNCTION addrasterconstraints(rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.addrasterconstraints(rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) IS 'args: rasttable, rastcolumn, srid, scale_x, scale_y, blocksize_x, blocksize_y, same_alignment, regular_blocking, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true of the constraint setting was accomplished and if issues a notice.';


--
-- Name: addrasterconstraints(name, name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.addrasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean DEFAULT true, scale_x boolean DEFAULT true, scale_y boolean DEFAULT true, blocksize_x boolean DEFAULT true, blocksize_y boolean DEFAULT true, same_alignment boolean DEFAULT true, regular_blocking boolean DEFAULT false, num_bands boolean DEFAULT true, pixel_types boolean DEFAULT true, nodata_values boolean DEFAULT true, out_db boolean DEFAULT true, extent boolean DEFAULT true) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		constraints text[];
	BEGIN
		IF srid IS TRUE THEN
			constraints := constraints || 'srid'::text;
		END IF;

		IF scale_x IS TRUE THEN
			constraints := constraints || 'scale_x'::text;
		END IF;

		IF scale_y IS TRUE THEN
			constraints := constraints || 'scale_y'::text;
		END IF;

		IF blocksize_x IS TRUE THEN
			constraints := constraints || 'blocksize_x'::text;
		END IF;

		IF blocksize_y IS TRUE THEN
			constraints := constraints || 'blocksize_y'::text;
		END IF;

		IF same_alignment IS TRUE THEN
			constraints := constraints || 'same_alignment'::text;
		END IF;

		IF regular_blocking IS TRUE THEN
			constraints := constraints || 'regular_blocking'::text;
		END IF;

		IF num_bands IS TRUE THEN
			constraints := constraints || 'num_bands'::text;
		END IF;

		IF pixel_types IS TRUE THEN
			constraints := constraints || 'pixel_types'::text;
		END IF;

		IF nodata_values IS TRUE THEN
			constraints := constraints || 'nodata_values'::text;
		END IF;

		IF out_db IS TRUE THEN
			constraints := constraints || 'out_db'::text;
		END IF;

		IF extent IS TRUE THEN
			constraints := constraints || 'extent'::text;
		END IF;

		RETURN AddRasterConstraints($1, $2, $3, VARIADIC constraints);
	END;
	$_$;


ALTER FUNCTION public.addrasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) OWNER TO postgres;

--
-- Name: FUNCTION addrasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.addrasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) IS 'args: rastschema, rasttable, rastcolumn, srid=true, scale_x=true, scale_y=true, blocksize_x=true, blocksize_y=true, same_alignment=true, regular_blocking=true, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true of the constraint setting was accomplished and if issues a notice.';


--
-- Name: checkauth(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.checkauth(text, text) RETURNS integer
    LANGUAGE sql
    AS $_$ SELECT CheckAuth('', $1, $2) $_$;


ALTER FUNCTION public.checkauth(text, text) OWNER TO postgres;

--
-- Name: checkauth(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.checkauth(text, text, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$ 
DECLARE
	schema text;
BEGIN
	IF NOT LongTransactionsEnabled() THEN
		RAISE EXCEPTION 'Long transaction support disabled, use EnableLongTransaction() to enable.';
	END IF;

	if ( $1 != '' ) THEN
		schema = $1;
	ELSE
		SELECT current_schema() into schema;
	END IF;

	-- TODO: check for an already existing trigger ?

	EXECUTE 'CREATE TRIGGER check_auth BEFORE UPDATE OR DELETE ON ' 
		|| quote_ident(schema) || '.' || quote_ident($2)
		||' FOR EACH ROW EXECUTE PROCEDURE CheckAuthTrigger('
		|| quote_literal($3) || ')';

	RETURN 0;
END;
$_$;


ALTER FUNCTION public.checkauth(text, text, text) OWNER TO postgres;

--
-- Name: disablelongtransactions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.disablelongtransactions() RETURNS text
    LANGUAGE plpgsql
    AS $$ 
DECLARE
	rec RECORD;

BEGIN

	--
	-- Drop all triggers applied by CheckAuth()
	--
	FOR rec IN
		SELECT c.relname, t.tgname, t.tgargs FROM pg_trigger t, pg_class c, pg_proc p
		WHERE p.proname = 'checkauthtrigger' and t.tgfoid = p.oid and t.tgrelid = c.oid
	LOOP
		EXECUTE 'DROP TRIGGER ' || quote_ident(rec.tgname) ||
			' ON ' || quote_ident(rec.relname);
	END LOOP;

	--
	-- Drop the authorization_table table
	--
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorization_table' LOOP
		DROP TABLE authorization_table;
	END LOOP;

	--
	-- Drop the authorized_tables view
	--
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorized_tables' LOOP
		DROP VIEW authorized_tables;
	END LOOP;

	RETURN 'Long transactions support disabled';
END;
$$;


ALTER FUNCTION public.disablelongtransactions() OWNER TO postgres;

--
-- Name: dropgeometrycolumn(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropgeometrycolumn(table_name character varying, column_name character varying) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
	ret text;
BEGIN
	SELECT DropGeometryColumn('','',$1,$2) into ret;
	RETURN ret;
END;
$_$;


ALTER FUNCTION public.dropgeometrycolumn(table_name character varying, column_name character varying) OWNER TO postgres;

--
-- Name: dropgeometrycolumn(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropgeometrycolumn(schema_name character varying, table_name character varying, column_name character varying) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
	ret text;
BEGIN
	SELECT DropGeometryColumn('',$1,$2,$3) into ret;
	RETURN ret;
END;
$_$;


ALTER FUNCTION public.dropgeometrycolumn(schema_name character varying, table_name character varying, column_name character varying) OWNER TO postgres;

--
-- Name: dropgeometrycolumn(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropgeometrycolumn(catalog_name character varying, schema_name character varying, table_name character varying, column_name character varying) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
	myrec RECORD;
	okay boolean;
	real_schema name;

BEGIN


	-- Find, check or fix schema_name
	IF ( schema_name != '' ) THEN
		okay = false;

		FOR myrec IN SELECT nspname FROM pg_namespace WHERE text(nspname) = schema_name LOOP
			okay := true;
		END LOOP;

		IF ( okay <>  true ) THEN
			RAISE NOTICE 'Invalid schema name - using current_schema()';
			SELECT current_schema() into real_schema;
		ELSE
			real_schema = schema_name;
		END IF;
	ELSE
		SELECT current_schema() into real_schema;
	END IF;

	-- Find out if the column is in the geometry_columns table
	okay = false;
	FOR myrec IN SELECT * from geometry_columns where f_table_schema = text(real_schema) and f_table_name = table_name and f_geometry_column = column_name LOOP
		okay := true;
	END LOOP;
	IF (okay <> true) THEN
		RAISE EXCEPTION 'column not found in geometry_columns table';
		RETURN false;
	END IF;

	-- Remove table column
	EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) || '.' ||
		quote_ident(table_name) || ' DROP COLUMN ' ||
		quote_ident(column_name);

	RETURN real_schema || '.' || table_name || '.' || column_name ||' effectively removed.';

END;
$$;


ALTER FUNCTION public.dropgeometrycolumn(catalog_name character varying, schema_name character varying, table_name character varying, column_name character varying) OWNER TO postgres;

--
-- Name: dropgeometrytable(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropgeometrytable(table_name character varying) RETURNS text
    LANGUAGE sql STRICT
    AS $_$ SELECT DropGeometryTable('','',$1) $_$;


ALTER FUNCTION public.dropgeometrytable(table_name character varying) OWNER TO postgres;

--
-- Name: dropgeometrytable(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropgeometrytable(schema_name character varying, table_name character varying) RETURNS text
    LANGUAGE sql STRICT
    AS $_$ SELECT DropGeometryTable('',$1,$2) $_$;


ALTER FUNCTION public.dropgeometrytable(schema_name character varying, table_name character varying) OWNER TO postgres;

--
-- Name: dropgeometrytable(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropgeometrytable(catalog_name character varying, schema_name character varying, table_name character varying) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
	real_schema name;

BEGIN

	IF ( schema_name = '' ) THEN
		SELECT current_schema() into real_schema;
	ELSE
		real_schema = schema_name;
	END IF;

	-- TODO: Should we warn if table doesn't exist probably instead just saying dropped
	-- Remove table
	EXECUTE 'DROP TABLE IF EXISTS '
		|| quote_ident(real_schema) || '.' ||
		quote_ident(table_name) || ' RESTRICT';

	RETURN
		real_schema || '.' ||
		table_name ||' dropped.';

END;
$$;


ALTER FUNCTION public.dropgeometrytable(catalog_name character varying, schema_name character varying, table_name character varying) OWNER TO postgres;

--
-- Name: dropoverviewconstraints(name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropoverviewconstraints(ovtable name, ovcolumn name) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT DropOverviewConstraints('', $1, $2) $_$;


ALTER FUNCTION public.dropoverviewconstraints(ovtable name, ovcolumn name) OWNER TO postgres;

--
-- Name: dropoverviewconstraints(name, name, name); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dropoverviewconstraints(ovschema name, ovtable name, ovcolumn name) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		schema name;
		sql text;
		rtn boolean;
	BEGIN
		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		rtn := _drop_overview_constraint(schema, $2, $3);
		IF rtn IS FALSE THEN
			RAISE EXCEPTION 'Unable to drop the overview constraint .  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$_$;


ALTER FUNCTION public.dropoverviewconstraints(ovschema name, ovtable name, ovcolumn name) OWNER TO postgres;

--
-- Name: droprasterconstraints(name, name, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.droprasterconstraints(rasttable name, rastcolumn name, VARIADIC constraints text[]) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT DropRasterConstraints('', $1, $2, VARIADIC $3) $_$;


ALTER FUNCTION public.droprasterconstraints(rasttable name, rastcolumn name, VARIADIC constraints text[]) OWNER TO postgres;

--
-- Name: droprasterconstraints(name, name, name, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.droprasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		max int;
		x int;
		schema name;
		sql text;
		kw text;
		rtn boolean;
		cnt int;
	BEGIN
		cnt := 0;
		max := array_length(constraints, 1);
		IF max < 1 THEN
			RAISE NOTICE 'No constraints indicated to be dropped.  Doing nothing';
			RETURN TRUE;
		END IF;

		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		<<kwloop>>
		FOR x in 1..max LOOP
			kw := trim(both from lower(constraints[x]));

			BEGIN
				CASE
					WHEN kw = 'srid' THEN
						RAISE NOTICE 'Dropping SRID constraint';
						rtn := _drop_raster_constraint_srid(schema, $2, $3);
					WHEN kw IN ('scale_x', 'scalex') THEN
						RAISE NOTICE 'Dropping scale-X constraint';
						rtn := _drop_raster_constraint_scale(schema, $2, $3, 'x');
					WHEN kw IN ('scale_y', 'scaley') THEN
						RAISE NOTICE 'Dropping scale-Y constraint';
						rtn := _drop_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw = 'scale' THEN
						RAISE NOTICE 'Dropping scale-X constraint';
						rtn := _drop_raster_constraint_scale(schema, $2, $3, 'x');
						RAISE NOTICE 'Dropping scale-Y constraint';
						rtn := _drop_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw IN ('blocksize_x', 'blocksizex', 'width') THEN
						RAISE NOTICE 'Dropping blocksize-X constraint';
						rtn := _drop_raster_constraint_blocksize(schema, $2, $3, 'width');
					WHEN kw IN ('blocksize_y', 'blocksizey', 'height') THEN
						RAISE NOTICE 'Dropping blocksize-Y constraint';
						rtn := _drop_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw = 'blocksize' THEN
						RAISE NOTICE 'Dropping blocksize-X constraint';
						rtn := _drop_raster_constraint_blocksize(schema, $2, $3, 'width');
						RAISE NOTICE 'Dropping blocksize-Y constraint';
						rtn := _drop_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw IN ('same_alignment', 'samealignment', 'alignment') THEN
						RAISE NOTICE 'Dropping alignment constraint';
						rtn := _drop_raster_constraint_alignment(schema, $2, $3);
					WHEN kw IN ('regular_blocking', 'regularblocking') THEN
						RAISE NOTICE 'Dropping regular blocking constraint';
						rtn := _drop_raster_constraint_regular_blocking(schema, $2, $3);
					WHEN kw IN ('num_bands', 'numbands') THEN
						RAISE NOTICE 'Dropping number of bands constraint';
						rtn := _drop_raster_constraint_num_bands(schema, $2, $3);
					WHEN kw IN ('pixel_types', 'pixeltypes') THEN
						RAISE NOTICE 'Dropping pixel type constraint';
						rtn := _drop_raster_constraint_pixel_types(schema, $2, $3);
					WHEN kw IN ('nodata_values', 'nodatavalues', 'nodata') THEN
						RAISE NOTICE 'Dropping nodata value constraint';
						rtn := _drop_raster_constraint_nodata_values(schema, $2, $3);
					WHEN kw IN ('out_db', 'outdb') THEN
						RAISE NOTICE 'Dropping out-of-database constraint';
						rtn := _drop_raster_constraint_out_db(schema, $2, $3);
					WHEN kw = 'extent' THEN
						RAISE NOTICE 'Dropping maximum extent constraint';
						rtn := _drop_raster_constraint_extent(schema, $2, $3);
					ELSE
						RAISE NOTICE 'Unknown constraint: %.  Skipping', quote_literal(constraints[x]);
						CONTINUE kwloop;
				END CASE;
			END;

			IF rtn IS FALSE THEN
				cnt := cnt + 1;
				RAISE WARNING 'Unable to drop constraint: %.  Skipping', quote_literal(constraints[x]);
			END IF;

		END LOOP kwloop;

		IF cnt = max THEN
			RAISE EXCEPTION 'None of the constraints specified could be dropped.  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$_$;


ALTER FUNCTION public.droprasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]) OWNER TO postgres;

--
-- Name: FUNCTION droprasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.droprasterconstraints(rastschema name, rasttable name, rastcolumn name, VARIADIC constraints text[]) IS 'args: rastschema, rasttable, rastcolumn, constraints - Drops PostGIS raster constraints that refer to a raster table column. Useful if you need to reload data or update your raster column data.';


--
-- Name: droprasterconstraints(name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.droprasterconstraints(rasttable name, rastcolumn name, srid boolean DEFAULT true, scale_x boolean DEFAULT true, scale_y boolean DEFAULT true, blocksize_x boolean DEFAULT true, blocksize_y boolean DEFAULT true, same_alignment boolean DEFAULT true, regular_blocking boolean DEFAULT true, num_bands boolean DEFAULT true, pixel_types boolean DEFAULT true, nodata_values boolean DEFAULT true, out_db boolean DEFAULT true, extent boolean DEFAULT true) RETURNS boolean
    LANGUAGE sql STRICT
    AS $_$ SELECT DropRasterConstraints('', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) $_$;


ALTER FUNCTION public.droprasterconstraints(rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) OWNER TO postgres;

--
-- Name: FUNCTION droprasterconstraints(rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.droprasterconstraints(rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) IS 'args: rasttable, rastcolumn, srid, scale_x, scale_y, blocksize_x, blocksize_y, same_alignment, regular_blocking, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Drops PostGIS raster constraints that refer to a raster table column. Useful if you need to reload data or update your raster column data.';


--
-- Name: droprasterconstraints(name, name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.droprasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean DEFAULT true, scale_x boolean DEFAULT true, scale_y boolean DEFAULT true, blocksize_x boolean DEFAULT true, blocksize_y boolean DEFAULT true, same_alignment boolean DEFAULT true, regular_blocking boolean DEFAULT true, num_bands boolean DEFAULT true, pixel_types boolean DEFAULT true, nodata_values boolean DEFAULT true, out_db boolean DEFAULT true, extent boolean DEFAULT true) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $_$
	DECLARE
		constraints text[];
	BEGIN
		IF srid IS TRUE THEN
			constraints := constraints || 'srid'::text;
		END IF;

		IF scale_x IS TRUE THEN
			constraints := constraints || 'scale_x'::text;
		END IF;

		IF scale_y IS TRUE THEN
			constraints := constraints || 'scale_y'::text;
		END IF;

		IF blocksize_x IS TRUE THEN
			constraints := constraints || 'blocksize_x'::text;
		END IF;

		IF blocksize_y IS TRUE THEN
			constraints := constraints || 'blocksize_y'::text;
		END IF;

		IF same_alignment IS TRUE THEN
			constraints := constraints || 'same_alignment'::text;
		END IF;

		IF regular_blocking IS TRUE THEN
			constraints := constraints || 'regular_blocking'::text;
		END IF;

		IF num_bands IS TRUE THEN
			constraints := constraints || 'num_bands'::text;
		END IF;

		IF pixel_types IS TRUE THEN
			constraints := constraints || 'pixel_types'::text;
		END IF;

		IF nodata_values IS TRUE THEN
			constraints := constraints || 'nodata_values'::text;
		END IF;

		IF out_db IS TRUE THEN
			constraints := constraints || 'out_db'::text;
		END IF;

		IF extent IS TRUE THEN
			constraints := constraints || 'extent'::text;
		END IF;

		RETURN DropRasterConstraints($1, $2, $3, VARIADIC constraints);
	END;
	$_$;


ALTER FUNCTION public.droprasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) OWNER TO postgres;

--
-- Name: FUNCTION droprasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.droprasterconstraints(rastschema name, rasttable name, rastcolumn name, srid boolean, scale_x boolean, scale_y boolean, blocksize_x boolean, blocksize_y boolean, same_alignment boolean, regular_blocking boolean, num_bands boolean, pixel_types boolean, nodata_values boolean, out_db boolean, extent boolean) IS 'args: rastschema, rasttable, rastcolumn, srid=true, scale_x=true, scale_y=true, blocksize_x=true, blocksize_y=true, same_alignment=true, regular_blocking=true, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Drops PostGIS raster constraints that refer to a raster table column. Useful if you need to reload data or update your raster column data.';


--
-- Name: enablelongtransactions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.enablelongtransactions() RETURNS text
    LANGUAGE plpgsql
    AS $$ 
DECLARE
	"query" text;
	exists bool;
	rec RECORD;

BEGIN

	exists = 'f';
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorization_table'
	LOOP
		exists = 't';
	END LOOP;

	IF NOT exists
	THEN
		"query" = 'CREATE TABLE authorization_table (
			toid oid, -- table oid
			rid text, -- row id
			expires timestamp,
			authid text
		)';
		EXECUTE "query";
	END IF;

	exists = 'f';
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorized_tables'
	LOOP
		exists = 't';
	END LOOP;

	IF NOT exists THEN
		"query" = 'CREATE VIEW authorized_tables AS ' ||
			'SELECT ' ||
			'n.nspname as schema, ' ||
			'c.relname as table, trim(' ||
			quote_literal(chr(92) || '000') ||
			' from t.tgargs) as id_column ' ||
			'FROM pg_trigger t, pg_class c, pg_proc p ' ||
			', pg_namespace n ' ||
			'WHERE p.proname = ' || quote_literal('checkauthtrigger') ||
			' AND c.relnamespace = n.oid' ||
			' AND t.tgfoid = p.oid and t.tgrelid = c.oid';
		EXECUTE "query";
	END IF;

	RETURN 'Long transactions support enabled';
END;
$$;


ALTER FUNCTION public.enablelongtransactions() OWNER TO postgres;

--
-- Name: find_srid(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_srid(character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
DECLARE
	schem text;
	tabl text;
	sr int4;
BEGIN
	IF $1 IS NULL THEN
	  RAISE EXCEPTION 'find_srid() - schema is NULL!';
	END IF;
	IF $2 IS NULL THEN
	  RAISE EXCEPTION 'find_srid() - table name is NULL!';
	END IF;
	IF $3 IS NULL THEN
	  RAISE EXCEPTION 'find_srid() - column name is NULL!';
	END IF;
	schem = $1;
	tabl = $2;
-- if the table contains a . and the schema is empty
-- split the table into a schema and a table
-- otherwise drop through to default behavior
	IF ( schem = '' and tabl LIKE '%.%' ) THEN
	 schem = substr(tabl,1,strpos(tabl,'.')-1);
	 tabl = substr(tabl,length(schem)+2);
	ELSE
	 schem = schem || '%';
	END IF;

	select SRID into sr from geometry_columns where f_table_schema like schem and f_table_name = tabl and f_geometry_column = $3;
	IF NOT FOUND THEN
	   RAISE EXCEPTION 'find_srid() - couldnt find the corresponding SRID - is the geometry registered in the GEOMETRY_COLUMNS table?  Is there an uppercase/lowercase missmatch?';
	END IF;
	return sr;
END;
$_$;


ALTER FUNCTION public.find_srid(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: get_proj4_from_srid(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_proj4_from_srid(integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
BEGIN
	RETURN proj4text::text FROM spatial_ref_sys WHERE srid= $1;
END;
$_$;


ALTER FUNCTION public.get_proj4_from_srid(integer) OWNER TO postgres;

--
-- Name: lockrow(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lockrow(text, text, text) RETURNS integer
    LANGUAGE sql STRICT
    AS $_$ SELECT LockRow(current_schema(), $1, $2, $3, now()::timestamp+'1:00'); $_$;


ALTER FUNCTION public.lockrow(text, text, text) OWNER TO postgres;

--
-- Name: lockrow(text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lockrow(text, text, text, text) RETURNS integer
    LANGUAGE sql STRICT
    AS $_$ SELECT LockRow($1, $2, $3, $4, now()::timestamp+'1:00'); $_$;


ALTER FUNCTION public.lockrow(text, text, text, text) OWNER TO postgres;

--
-- Name: lockrow(text, text, text, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lockrow(text, text, text, timestamp without time zone) RETURNS integer
    LANGUAGE sql STRICT
    AS $_$ SELECT LockRow(current_schema(), $1, $2, $3, $4); $_$;


ALTER FUNCTION public.lockrow(text, text, text, timestamp without time zone) OWNER TO postgres;

--
-- Name: lockrow(text, text, text, text, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lockrow(text, text, text, text, timestamp without time zone) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $_$ 
DECLARE
	myschema alias for $1;
	mytable alias for $2;
	myrid   alias for $3;
	authid alias for $4;
	expires alias for $5;
	ret int;
	mytoid oid;
	myrec RECORD;
	
BEGIN

	IF NOT LongTransactionsEnabled() THEN
		RAISE EXCEPTION 'Long transaction support disabled, use EnableLongTransaction() to enable.';
	END IF;

	EXECUTE 'DELETE FROM authorization_table WHERE expires < now()'; 

	SELECT c.oid INTO mytoid FROM pg_class c, pg_namespace n
		WHERE c.relname = mytable
		AND c.relnamespace = n.oid
		AND n.nspname = myschema;

	-- RAISE NOTICE 'toid: %', mytoid;

	FOR myrec IN SELECT * FROM authorization_table WHERE 
		toid = mytoid AND rid = myrid
	LOOP
		IF myrec.authid != authid THEN
			RETURN 0;
		ELSE
			RETURN 1;
		END IF;
	END LOOP;

	EXECUTE 'INSERT INTO authorization_table VALUES ('||
		quote_literal(mytoid::text)||','||quote_literal(myrid)||
		','||quote_literal(expires::text)||
		','||quote_literal(authid) ||')';

	GET DIAGNOSTICS ret = ROW_COUNT;

	RETURN ret;
END;
$_$;


ALTER FUNCTION public.lockrow(text, text, text, text, timestamp without time zone) OWNER TO postgres;

--
-- Name: longtransactionsenabled(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.longtransactionsenabled() RETURNS boolean
    LANGUAGE plpgsql
    AS $$ 
DECLARE
	rec RECORD;
BEGIN
	FOR rec IN SELECT oid FROM pg_class WHERE relname = 'authorized_tables'
	LOOP
		return 't';
	END LOOP;
	return 'f';
END;
$$;


ALTER FUNCTION public.longtransactionsenabled() OWNER TO postgres;

--
-- Name: populate_geometry_columns(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.populate_geometry_columns(use_typmod boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
	inserted    integer;
	oldcount    integer;
	probed      integer;
	stale       integer;
	gcs         RECORD;
	gc          RECORD;
	gsrid       integer;
	gndims      integer;
	gtype       text;
	query       text;
	gc_is_valid boolean;

BEGIN
	SELECT count(*) INTO oldcount FROM geometry_columns;
	inserted := 0;

	-- Count the number of geometry columns in all tables and views
	SELECT count(DISTINCT c.oid) INTO probed
	FROM pg_class c,
		 pg_attribute a,
		 pg_type t,
		 pg_namespace n
	WHERE (c.relkind = 'r' OR c.relkind = 'v')
		AND t.typname = 'geometry'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND n.nspname NOT ILIKE 'pg_temp%' AND c.relname != 'raster_columns' ;

	-- Iterate through all non-dropped geometry columns
	RAISE DEBUG 'Processing Tables.....';

	FOR gcs IN
	SELECT DISTINCT ON (c.oid) c.oid, n.nspname, c.relname
		FROM pg_class c,
			 pg_attribute a,
			 pg_type t,
			 pg_namespace n
		WHERE c.relkind = 'r'
		AND t.typname = 'geometry'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND n.nspname NOT ILIKE 'pg_temp%' AND c.relname != 'raster_columns' 
	LOOP

		inserted := inserted + populate_geometry_columns(gcs.oid, use_typmod);
	END LOOP;

	IF oldcount > inserted THEN
	    stale = oldcount-inserted;
	ELSE
	    stale = 0;
	END IF;

	RETURN 'probed:' ||probed|| ' inserted:'||inserted;
END

$$;


ALTER FUNCTION public.populate_geometry_columns(use_typmod boolean) OWNER TO postgres;

--
-- Name: populate_geometry_columns(oid, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.populate_geometry_columns(tbl_oid oid, use_typmod boolean DEFAULT true) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	gcs         RECORD;
	gc          RECORD;
	gc_old      RECORD;
	gsrid       integer;
	gndims      integer;
	gtype       text;
	query       text;
	gc_is_valid boolean;
	inserted    integer;
	constraint_successful boolean := false;

BEGIN
	inserted := 0;

	-- Iterate through all geometry columns in this table
	FOR gcs IN
	SELECT n.nspname, c.relname, a.attname
		FROM pg_class c,
			 pg_attribute a,
			 pg_type t,
			 pg_namespace n
		WHERE c.relkind = 'r'
		AND t.typname = 'geometry'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND n.nspname NOT ILIKE 'pg_temp%'
		AND c.oid = tbl_oid
	LOOP

        RAISE DEBUG 'Processing table %.%.%', gcs.nspname, gcs.relname, gcs.attname;
    
        gc_is_valid := true;
        -- Find the srid, coord_dimension, and type of current geometry
        -- in geometry_columns -- which is now a view
        
        SELECT type, srid, coord_dimension INTO gc_old 
            FROM geometry_columns 
            WHERE f_table_schema = gcs.nspname AND f_table_name = gcs.relname AND f_geometry_column = gcs.attname; 
            
        IF upper(gc_old.type) = 'GEOMETRY' THEN
        -- This is an unconstrained geometry we need to do something
        -- We need to figure out what to set the type by inspecting the data
            EXECUTE 'SELECT st_srid(' || quote_ident(gcs.attname) || ') As srid, GeometryType(' || quote_ident(gcs.attname) || ') As type, ST_NDims(' || quote_ident(gcs.attname) || ') As dims ' ||
                     ' FROM ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || 
                     ' WHERE ' || quote_ident(gcs.attname) || ' IS NOT NULL LIMIT 1;'
                INTO gc;
            IF gc IS NULL THEN -- there is no data so we can not determine geometry type
            	RAISE WARNING 'No data in table %.%, so no information to determine geometry type and srid', gcs.nspname, gcs.relname;
            	RETURN 0;
            END IF;
            gsrid := gc.srid; gtype := gc.type; gndims := gc.dims;
            	
            IF use_typmod THEN
                BEGIN
                    EXECUTE 'ALTER TABLE ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || ' ALTER COLUMN ' || quote_ident(gcs.attname) || 
                        ' TYPE geometry(' || postgis_type_name(gtype, gndims, true) || ', ' || gsrid::text  || ') ';
                    inserted := inserted + 1;
                EXCEPTION
                        WHEN invalid_parameter_value THEN
                        RAISE WARNING 'Could not convert ''%'' in ''%.%'' to use typmod with srid %, type: % ', quote_ident(gcs.attname), quote_ident(gcs.nspname), quote_ident(gcs.relname), gsrid, postgis_type_name(gtype, gndims, true);
                            gc_is_valid := false;
                END;
                
            ELSE
                -- Try to apply srid check to column
            	constraint_successful = false;
                IF (gsrid > 0 AND postgis_constraint_srid(gcs.nspname, gcs.relname,gcs.attname) IS NULL ) THEN
                    BEGIN
                        EXECUTE 'ALTER TABLE ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || 
                                 ' ADD CONSTRAINT ' || quote_ident('enforce_srid_' || gcs.attname) || 
                                 ' CHECK (st_srid(' || quote_ident(gcs.attname) || ') = ' || gsrid || ')';
                        constraint_successful := true;
                    EXCEPTION
                        WHEN check_violation THEN
                            RAISE WARNING 'Not inserting ''%'' in ''%.%'' into geometry_columns: could not apply constraint CHECK (st_srid(%) = %)', quote_ident(gcs.attname), quote_ident(gcs.nspname), quote_ident(gcs.relname), quote_ident(gcs.attname), gsrid;
                            gc_is_valid := false;
                    END;
                END IF;
                
                -- Try to apply ndims check to column
                IF (gndims IS NOT NULL AND postgis_constraint_dims(gcs.nspname, gcs.relname,gcs.attname) IS NULL ) THEN
                    BEGIN
                        EXECUTE 'ALTER TABLE ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || '
                                 ADD CONSTRAINT ' || quote_ident('enforce_dims_' || gcs.attname) || '
                                 CHECK (st_ndims(' || quote_ident(gcs.attname) || ') = '||gndims||')';
                        constraint_successful := true;
                    EXCEPTION
                        WHEN check_violation THEN
                            RAISE WARNING 'Not inserting ''%'' in ''%.%'' into geometry_columns: could not apply constraint CHECK (st_ndims(%) = %)', quote_ident(gcs.attname), quote_ident(gcs.nspname), quote_ident(gcs.relname), quote_ident(gcs.attname), gndims;
                            gc_is_valid := false;
                    END;
                END IF;
    
                -- Try to apply geometrytype check to column
                IF (gtype IS NOT NULL AND postgis_constraint_type(gcs.nspname, gcs.relname,gcs.attname) IS NULL ) THEN
                    BEGIN
                        EXECUTE 'ALTER TABLE ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || '
                        ADD CONSTRAINT ' || quote_ident('enforce_geotype_' || gcs.attname) || '
                        CHECK ((geometrytype(' || quote_ident(gcs.attname) || ') = ' || quote_literal(gtype) || ') OR (' || quote_ident(gcs.attname) || ' IS NULL))';
                        constraint_successful := true;
                    EXCEPTION
                        WHEN check_violation THEN
                            -- No geometry check can be applied. This column contains a number of geometry types.
                            RAISE WARNING 'Could not add geometry type check (%) to table column: %.%.%', gtype, quote_ident(gcs.nspname),quote_ident(gcs.relname),quote_ident(gcs.attname);
                    END;
                END IF;
                 --only count if we were successful in applying at least one constraint
                IF constraint_successful THEN
                	inserted := inserted + 1;
                END IF;
            END IF;	        
	    END IF;

	END LOOP;

	RETURN inserted;
END

$$;


ALTER FUNCTION public.populate_geometry_columns(tbl_oid oid, use_typmod boolean) OWNER TO postgres;

--
-- Name: postgis_constraint_dims(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_constraint_dims(geomschema text, geomtable text, geomcolumn text) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$
SELECT  replace(split_part(s.consrc, ' = ', 2), ')', '')::integer
		 FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
		 WHERE n.nspname = $1
		 AND c.relname = $2
		 AND a.attname = $3
		 AND a.attrelid = c.oid
		 AND s.connamespace = n.oid
		 AND s.conrelid = c.oid
		 AND a.attnum = ANY (s.conkey)
		 AND s.consrc LIKE '%ndims(% = %';
$_$;


ALTER FUNCTION public.postgis_constraint_dims(geomschema text, geomtable text, geomcolumn text) OWNER TO postgres;

--
-- Name: postgis_constraint_srid(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_constraint_srid(geomschema text, geomtable text, geomcolumn text) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$
SELECT replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', '')::integer
		 FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
		 WHERE n.nspname = $1
		 AND c.relname = $2
		 AND a.attname = $3
		 AND a.attrelid = c.oid
		 AND s.connamespace = n.oid
		 AND s.conrelid = c.oid
		 AND a.attnum = ANY (s.conkey)
		 AND s.consrc LIKE '%srid(% = %';
$_$;


ALTER FUNCTION public.postgis_constraint_srid(geomschema text, geomtable text, geomcolumn text) OWNER TO postgres;

--
-- Name: postgis_constraint_type(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_constraint_type(geomschema text, geomtable text, geomcolumn text) RETURNS character varying
    LANGUAGE sql STABLE STRICT
    AS $_$
SELECT  replace(split_part(s.consrc, '''', 2), ')', '')::varchar		
		 FROM pg_class c, pg_namespace n, pg_attribute a, pg_constraint s
		 WHERE n.nspname = $1
		 AND c.relname = $2
		 AND a.attname = $3
		 AND a.attrelid = c.oid
		 AND s.connamespace = n.oid
		 AND s.conrelid = c.oid
		 AND a.attnum = ANY (s.conkey)
		 AND s.consrc LIKE '%geometrytype(% = %';
$_$;


ALTER FUNCTION public.postgis_constraint_type(geomschema text, geomtable text, geomcolumn text) OWNER TO postgres;

--
-- Name: postgis_full_version(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_full_version() RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
	libver text;
	svnver text;
	projver text;
	geosver text;
	gdalver text;
	libxmlver text;
	dbproc text;
	relproc text;
	fullver text;
	rast_lib_ver text;
	rast_scr_ver text;
	topo_scr_ver text;
	json_lib_ver text;
BEGIN
	SELECT postgis_lib_version() INTO libver;
	SELECT postgis_proj_version() INTO projver;
	SELECT postgis_geos_version() INTO geosver;
	SELECT postgis_libjson_version() INTO json_lib_ver;
	BEGIN
		SELECT postgis_gdal_version() INTO gdalver;
	EXCEPTION
		WHEN undefined_function THEN
			gdalver := NULL;
			RAISE NOTICE 'Function postgis_gdal_version() not found.  Is raster support enabled and rtpostgis.sql installed?';
	END;
	SELECT postgis_libxml_version() INTO libxmlver;
	SELECT postgis_scripts_installed() INTO dbproc;
	SELECT postgis_scripts_released() INTO relproc;
	select postgis_svn_version() INTO svnver;
	BEGIN
		SELECT postgis_topology_scripts_installed() INTO topo_scr_ver;
	EXCEPTION
		WHEN undefined_function THEN
			topo_scr_ver := NULL;
			RAISE NOTICE 'Function postgis_topology_scripts_installed() not found. Is topology support enabled and topology.sql installed?';
	END;

	BEGIN
		SELECT postgis_raster_scripts_installed() INTO rast_scr_ver;
	EXCEPTION
		WHEN undefined_function THEN
			rast_scr_ver := NULL;
			RAISE NOTICE 'Function postgis_raster_scripts_installed() not found. Is raster support enabled and rtpostgis.sql installed?';
	END;

	BEGIN
		SELECT postgis_raster_lib_version() INTO rast_lib_ver;
	EXCEPTION
		WHEN undefined_function THEN
			rast_lib_ver := NULL;
			RAISE NOTICE 'Function postgis_raster_lib_version() not found. Is raster support enabled and rtpostgis.sql installed?';
	END;

	fullver = 'POSTGIS="' || libver;

	IF  svnver IS NOT NULL THEN
		fullver = fullver || ' r' || svnver;
	END IF;

	fullver = fullver || '"';

	IF  geosver IS NOT NULL THEN
		fullver = fullver || ' GEOS="' || geosver || '"';
	END IF;

	IF  projver IS NOT NULL THEN
		fullver = fullver || ' PROJ="' || projver || '"';
	END IF;

	IF  gdalver IS NOT NULL THEN
		fullver = fullver || ' GDAL="' || gdalver || '"';
	END IF;

	IF  libxmlver IS NOT NULL THEN
		fullver = fullver || ' LIBXML="' || libxmlver || '"';
	END IF;

	IF json_lib_ver IS NOT NULL THEN
		fullver = fullver || ' LIBJSON="' || json_lib_ver || '"';
	END IF;

	-- fullver = fullver || ' DBPROC="' || dbproc || '"';
	-- fullver = fullver || ' RELPROC="' || relproc || '"';

	IF dbproc != relproc THEN
		fullver = fullver || ' (core procs from "' || dbproc || '" need upgrade)';
	END IF;

	IF topo_scr_ver IS NOT NULL THEN
		fullver = fullver || ' TOPOLOGY';
		IF topo_scr_ver != relproc THEN
			fullver = fullver || ' (topology procs from "' || topo_scr_ver || '" need upgrade)';
		END IF;
	END IF;

	IF rast_lib_ver IS NOT NULL THEN
		fullver = fullver || ' RASTER';
		IF rast_lib_ver != relproc THEN
			fullver = fullver || ' (raster lib from "' || rast_lib_ver || '" need upgrade)';
		END IF;
	END IF;

	IF rast_scr_ver IS NOT NULL AND rast_scr_ver != relproc THEN
		fullver = fullver || ' (raster procs from "' || rast_scr_ver || '" need upgrade)';
	END IF;

	RETURN fullver;
END
$$;


ALTER FUNCTION public.postgis_full_version() OWNER TO postgres;

--
-- Name: postgis_raster_scripts_installed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_raster_scripts_installed() RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT '2.0.1'::text || ' r' || 9979::text AS version $$;


ALTER FUNCTION public.postgis_raster_scripts_installed() OWNER TO postgres;

--
-- Name: postgis_scripts_build_date(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_scripts_build_date() RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$SELECT '2012-11-16 18:39:39'::text AS version$$;


ALTER FUNCTION public.postgis_scripts_build_date() OWNER TO postgres;

--
-- Name: postgis_scripts_installed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_scripts_installed() RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT '2.0.1'::text || ' r' || 9979::text AS version $$;


ALTER FUNCTION public.postgis_scripts_installed() OWNER TO postgres;

--
-- Name: postgis_topology_scripts_installed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_topology_scripts_installed() RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT '2.0.1'::text || ' r' || 9979::text AS version $$;


ALTER FUNCTION public.postgis_topology_scripts_installed() OWNER TO postgres;

--
-- Name: postgis_type_name(character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.postgis_type_name(geomname character varying, coord_dimension integer, use_new_name boolean DEFAULT true) RETURNS character varying
    LANGUAGE sql IMMUTABLE STRICT COST 200
    AS $_$
 SELECT CASE WHEN $3 THEN new_name ELSE old_name END As geomname
 	FROM 
 	( VALUES
 		 ('GEOMETRY', 'Geometry', 2) ,
 		 	('GEOMETRY', 'GeometryZ', 3) ,
 		 	('GEOMETRY', 'GeometryZM', 4) ,
			('GEOMETRYCOLLECTION', 'GeometryCollection', 2) ,
			('GEOMETRYCOLLECTION', 'GeometryCollectionZ', 3) ,
			('GEOMETRYCOLLECTIONM', 'GeometryCollectionM', 3) ,
			('GEOMETRYCOLLECTION', 'GeometryCollectionZM', 4) ,
			
			('POINT', 'Point',2) ,
			('POINTM','PointM',3) ,
			('POINT', 'PointZ',3) ,
			('POINT', 'PointZM',4) ,
			
			('MULTIPOINT','MultiPoint',2) ,
			('MULTIPOINT','MultiPointZ',3) ,
			('MULTIPOINTM','MultiPointM',3) ,
			('MULTIPOINT','MultiPointZM',4) ,
			
			('POLYGON', 'Polygon',2) ,
			('POLYGON', 'PolygonZ',3) ,
			('POLYGONM', 'PolygonM',3) ,
			('POLYGON', 'PolygonZM',4) ,
			
			('MULTIPOLYGON', 'MultiPolygon',2) ,
			('MULTIPOLYGON', 'MultiPolygonZ',3) ,
			('MULTIPOLYGONM', 'MultiPolygonM',3) ,
			('MULTIPOLYGON', 'MultiPolygonZM',4) ,
			
			('MULTILINESTRING', 'MultiLineString',2) ,
			('MULTILINESTRING', 'MultiLineStringZ',3) ,
			('MULTILINESTRINGM', 'MultiLineStringM',3) ,
			('MULTILINESTRING', 'MultiLineStringZM',4) ,
			
			('LINESTRING', 'LineString',2) ,
			('LINESTRING', 'LineStringZ',3) ,
			('LINESTRINGM', 'LineStringM',3) ,
			('LINESTRING', 'LineStringZM',4) ,
			
			('CIRCULARSTRING', 'CircularString',2) ,
			('CIRCULARSTRING', 'CircularStringZ',3) ,
			('CIRCULARSTRINGM', 'CircularStringM',3) ,
			('CIRCULARSTRING', 'CircularStringZM',4) ,
			
			('COMPOUNDCURVE', 'CompoundCurve',2) ,
			('COMPOUNDCURVE', 'CompoundCurveZ',3) ,
			('COMPOUNDCURVEM', 'CompoundCurveM',3) ,
			('COMPOUNDCURVE', 'CompoundCurveZM',4) ,
			
			('CURVEPOLYGON', 'CurvePolygon',2) ,
			('CURVEPOLYGON', 'CurvePolygonZ',3) ,
			('CURVEPOLYGONM', 'CurvePolygonM',3) ,
			('CURVEPOLYGON', 'CurvePolygonZM',4) ,
			
			('MULTICURVE', 'MultiCurve',2 ) ,
			('MULTICURVE', 'MultiCurveZ',3 ) ,
			('MULTICURVEM', 'MultiCurveM',3 ) ,
			('MULTICURVE', 'MultiCurveZM',4 ) ,
			
			('MULTISURFACE', 'MultiSurface', 2) ,
			('MULTISURFACE', 'MultiSurfaceZ', 3) ,
			('MULTISURFACEM', 'MultiSurfaceM', 3) ,
			('MULTISURFACE', 'MultiSurfaceZM', 4) ,
			
			('POLYHEDRALSURFACE', 'PolyhedralSurface',2) ,
			('POLYHEDRALSURFACE', 'PolyhedralSurfaceZ',3) ,
			('POLYHEDRALSURFACEM', 'PolyhedralSurfaceM',3) ,
			('POLYHEDRALSURFACE', 'PolyhedralSurfaceZM',4) ,
			
			('TRIANGLE', 'Triangle',2) ,
			('TRIANGLE', 'TriangleZ',3) ,
			('TRIANGLEM', 'TriangleM',3) ,
			('TRIANGLE', 'TriangleZM',4) ,

			('TIN', 'Tin', 2),
			('TIN', 'TinZ', 3),
			('TIN', 'TinM', 3),
			('TIN', 'TinZM', 4) )
			 As g(old_name, new_name, coord_dimension)
		WHERE (upper(old_name) = upper($1) OR upper(new_name) = upper($1))
			AND coord_dimension = $2;
$_$;


ALTER FUNCTION public.postgis_type_name(geomname character varying, coord_dimension integer, use_new_name boolean) OWNER TO postgres;

--
-- Name: st_approxcount(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxcount(rastertable text, rastercolumn text, sample_percent double precision) RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_count($1, $2, 1, TRUE, $3) $_$;


ALTER FUNCTION public.st_approxcount(rastertable text, rastercolumn text, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxcount(text, text, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxcount(rastertable text, rastercolumn text, exclude_nodata_value boolean, sample_percent double precision DEFAULT 0.1) RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_count($1, $2, 1, $3, $4) $_$;


ALTER FUNCTION public.st_approxcount(rastertable text, rastercolumn text, exclude_nodata_value boolean, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxcount(text, text, integer, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxcount(rastertable text, rastercolumn text, nband integer, sample_percent double precision) RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_count($1, $2, $3, TRUE, $4) $_$;


ALTER FUNCTION public.st_approxcount(rastertable text, rastercolumn text, nband integer, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxcount(text, text, integer, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxcount(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, sample_percent double precision DEFAULT 0.1) RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_count($1, $2, $3, $4, $5) $_$;


ALTER FUNCTION public.st_approxcount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxhistogram(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, sample_percent double precision) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, 1, TRUE, $3, 0, NULL, FALSE) $_$;


ALTER FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxhistogram(text, text, integer, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, sample_percent double precision) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, $3, TRUE, $4, 0, NULL, FALSE) $_$;


ALTER FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxhistogram(text, text, integer, double precision, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, sample_percent double precision, bins integer, "right" boolean) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, $3, TRUE, $4, $5, NULL, $6) $_$;


ALTER FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, sample_percent double precision, bins integer, "right" boolean) OWNER TO postgres;

--
-- Name: st_approxhistogram(text, text, integer, boolean, double precision, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision, bins integer, "right" boolean) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, $3, $4, $5, $6, NULL, $7) $_$;


ALTER FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision, bins integer, "right" boolean) OWNER TO postgres;

--
-- Name: st_approxhistogram(text, text, integer, double precision, integer, double precision[], boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, sample_percent double precision, bins integer, width double precision[] DEFAULT NULL::double precision[], "right" boolean DEFAULT false) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, $3, TRUE, $4, $5, $6, $7) $_$;


ALTER FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, sample_percent double precision, bins integer, width double precision[], "right" boolean) OWNER TO postgres;

--
-- Name: st_approxhistogram(text, text, integer, boolean, double precision, integer, double precision[], boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, sample_percent double precision DEFAULT 0.1, bins integer DEFAULT 0, width double precision[] DEFAULT NULL::double precision[], "right" boolean DEFAULT false) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_histogram($1, $2, $3, $4, $5, $6, $7, $8) $_$;


ALTER FUNCTION public.st_approxhistogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision, bins integer, width double precision[], "right" boolean) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, quantiles double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_quantile($1, $2, 1, TRUE, 0.1, $3) $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, quantiles double precision[]) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE
    AS $_$ SELECT (_st_quantile($1, $2, 1, TRUE, 0.1, ARRAY[$3]::double precision[])).value $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, quantile double precision) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, exclude_nodata_value boolean, quantile double precision DEFAULT NULL::double precision) RETURNS double precision
    LANGUAGE sql STABLE
    AS $_$ SELECT (_st_quantile($1, $2, 1, $3, 0.1, ARRAY[$4]::double precision[])).value $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, exclude_nodata_value boolean, quantile double precision) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, double precision, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, sample_percent double precision, quantiles double precision[] DEFAULT NULL::double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_quantile($1, $2, 1, TRUE, $3, $4) $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, sample_percent double precision, quantiles double precision[]) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, sample_percent double precision, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_quantile($1, $2, 1, TRUE, $3, ARRAY[$4]::double precision[])).value $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, sample_percent double precision, quantile double precision) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, integer, double precision, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, sample_percent double precision, quantiles double precision[] DEFAULT NULL::double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_quantile($1, $2, $3, TRUE, $4, $5) $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, sample_percent double precision, quantiles double precision[]) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, integer, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, sample_percent double precision, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_quantile($1, $2, $3, TRUE, $4, ARRAY[$5]::double precision[])).value $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, sample_percent double precision, quantile double precision) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, integer, boolean, double precision, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, sample_percent double precision DEFAULT 0.1, quantiles double precision[] DEFAULT NULL::double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_quantile($1, $2, $3, $4, $5, $6) $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision, quantiles double precision[]) OWNER TO postgres;

--
-- Name: st_approxquantile(text, text, integer, boolean, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_quantile($1, $2, $3, $4, $5, ARRAY[$6]::double precision[])).value $_$;


ALTER FUNCTION public.st_approxquantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision, quantile double precision) OWNER TO postgres;

--
-- Name: st_approxsummarystats(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, exclude_nodata_value boolean) RETURNS public.summarystats
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_summarystats($1, $2, 1, $3, 0.1) $_$;


ALTER FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, exclude_nodata_value boolean) OWNER TO postgres;

--
-- Name: st_approxsummarystats(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, sample_percent double precision) RETURNS public.summarystats
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_summarystats($1, $2, 1, TRUE, $3) $_$;


ALTER FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxsummarystats(text, text, integer, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, nband integer, sample_percent double precision) RETURNS public.summarystats
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_summarystats($1, $2, $3, TRUE, $4) $_$;


ALTER FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, nband integer, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_approxsummarystats(text, text, integer, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, sample_percent double precision DEFAULT 0.1) RETURNS public.summarystats
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_summarystats($1, $2, $3, $4, $5) $_$;


ALTER FUNCTION public.st_approxsummarystats(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, sample_percent double precision) OWNER TO postgres;

--
-- Name: st_area(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_area(text) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_Area($1::geometry);  $_$;


ALTER FUNCTION public.st_area(text) OWNER TO postgres;

--
-- Name: st_asewkt(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_asewkt(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsEWKT($1::geometry);  $_$;


ALTER FUNCTION public.st_asewkt(text) OWNER TO postgres;

--
-- Name: st_asgeojson(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_asgeojson(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT _ST_AsGeoJson(1, $1::geometry,15,0);  $_$;


ALTER FUNCTION public.st_asgeojson(text) OWNER TO postgres;

--
-- Name: st_asgml(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_asgml(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT _ST_AsGML(2,$1::geometry,15,0, NULL);  $_$;


ALTER FUNCTION public.st_asgml(text) OWNER TO postgres;

--
-- Name: st_askml(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_askml(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT _ST_AsKML(2, $1::geometry, 15, null);  $_$;


ALTER FUNCTION public.st_askml(text) OWNER TO postgres;

--
-- Name: st_assvg(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_assvg(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsSVG($1::geometry,0,15);  $_$;


ALTER FUNCTION public.st_assvg(text) OWNER TO postgres;

--
-- Name: st_astext(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_astext(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsText($1::geometry);  $_$;


ALTER FUNCTION public.st_astext(text) OWNER TO postgres;

--
-- Name: st_count(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_count(rastertable text, rastercolumn text, exclude_nodata_value boolean) RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_count($1, $2, 1, $3, 1) $_$;


ALTER FUNCTION public.st_count(rastertable text, rastercolumn text, exclude_nodata_value boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_count(rastertable text, rastercolumn text, exclude_nodata_value boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_count(rastertable text, rastercolumn text, exclude_nodata_value boolean) IS 'args: rastertable, rastercolumn, exclude_nodata_value - Returns the number of pixels in a given band of a raster or raster coverage. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the nodata value.';


--
-- Name: st_count(text, text, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_count(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true) RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_count($1, $2, $3, $4, 1) $_$;


ALTER FUNCTION public.st_count(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_count(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_count(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true - Returns the number of pixels in a given band of a raster or raster coverage. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the nodata value.';


--
-- Name: st_coveredby(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_coveredby(text, text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT ST_CoveredBy($1::geometry, $2::geometry);  $_$;


ALTER FUNCTION public.st_coveredby(text, text) OWNER TO postgres;

--
-- Name: st_covers(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_covers(text, text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT ST_Covers($1::geometry, $2::geometry);  $_$;


ALTER FUNCTION public.st_covers(text, text) OWNER TO postgres;

--
-- Name: st_distance(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_distance(text, text) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_Distance($1::geometry, $2::geometry);  $_$;


ALTER FUNCTION public.st_distance(text, text) OWNER TO postgres;

--
-- Name: st_distinct4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_distinct4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT COUNT(DISTINCT unnest)::float FROM unnest($1) $_$;


ALTER FUNCTION public.st_distinct4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_distinct4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_distinct4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the number of unique pixel values in a neighborhood.';


--
-- Name: st_dwithin(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_dwithin(text, text, double precision) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT ST_DWithin($1::geometry, $2::geometry, $3);  $_$;


ALTER FUNCTION public.st_dwithin(text, text, double precision) OWNER TO postgres;

--
-- Name: st_histogram(text, text, integer, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, "right" boolean) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, $3, TRUE, 1, $4, NULL, $5) $_$;


ALTER FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, "right" boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, "right" boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, "right" boolean) IS 'args: rastertable, rastercolumn, nband, bins, right - Returns a set of histogram summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';


--
-- Name: st_histogram(text, text, integer, boolean, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, "right" boolean) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_histogram($1, $2, $3, $4, 1, $5, NULL, $6) $_$;


ALTER FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, "right" boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, "right" boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, "right" boolean) IS 'args: rastertable, rastercolumn, nband, exclude_nodata_value, bins, right - Returns a set of histogram summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';


--
-- Name: st_histogram(text, text, integer, integer, double precision[], boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, width double precision[] DEFAULT NULL::double precision[], "right" boolean DEFAULT false) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_histogram($1, $2, $3, TRUE, 1, $4, $5, $6) $_$;


ALTER FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, width double precision[], "right" boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, width double precision[], "right" boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, bins integer, width double precision[], "right" boolean) IS 'args: rastertable, rastercolumn, nband=1, bins, width=NULL, right=false - Returns a set of histogram summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';


--
-- Name: st_histogram(text, text, integer, boolean, integer, double precision[], boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, bins integer DEFAULT 0, width double precision[] DEFAULT NULL::double precision[], "right" boolean DEFAULT false) RETURNS SETOF public.histogram
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_histogram($1, $2, $3, $4, 1, $5, $6, $7) $_$;


ALTER FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, width double precision[], "right" boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, width double precision[], "right" boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_histogram(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, bins integer, width double precision[], "right" boolean) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true, bins=autocomputed, width=NULL, right=false - Returns a set of histogram summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';


--
-- Name: st_intersects(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_intersects(text, text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT ST_Intersects($1::geometry, $2::geometry);  $_$;


ALTER FUNCTION public.st_intersects(text, text) OWNER TO postgres;

--
-- Name: st_length(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_length(text) RETURNS double precision
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_Length($1::geometry);  $_$;


ALTER FUNCTION public.st_length(text) OWNER TO postgres;

--
-- Name: st_max4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_max4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        _matrix float[][];
        max float;
    BEGIN
        _matrix := matrix;
        max := '-Infinity'::float;
        FOR x in array_lower(_matrix, 1)..array_upper(_matrix, 1) LOOP
            FOR y in array_lower(_matrix, 2)..array_upper(_matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF NOT nodatamode = 'ignore' THEN
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                IF max < _matrix[x][y] THEN
                    max := _matrix[x][y];
                END IF;
            END LOOP;
        END LOOP;
        RETURN max;
    END;
    $$;


ALTER FUNCTION public.st_max4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_max4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_max4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the maximum pixel value in a neighborhood.';


--
-- Name: st_mean4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_mean4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        _matrix float[][];
        sum float;
        count float;
    BEGIN
        _matrix := matrix;
        sum := 0;
        count := 0;
        FOR x in array_lower(matrix, 1)..array_upper(matrix, 1) LOOP
            FOR y in array_lower(matrix, 2)..array_upper(matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF nodatamode = 'ignore' THEN
                        _matrix[x][y] := 0;
                    ELSE
                        _matrix[x][y] := nodatamode::float;
                        count := count + 1;
                    END IF;
                ELSE
                    count := count + 1;
                END IF;
                sum := sum + _matrix[x][y];
            END LOOP;
        END LOOP;
        IF count = 0 THEN
            RETURN NULL;
        END IF;
        RETURN sum / count;
    END;
    $$;


ALTER FUNCTION public.st_mean4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_mean4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_mean4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the mean pixel value in a neighborhood.';


--
-- Name: st_min4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_min4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        _matrix float[][];
        min float;
    BEGIN
        _matrix := matrix;
        min := 'Infinity'::float;
        FOR x in array_lower(_matrix, 1)..array_upper(_matrix, 1) LOOP
            FOR y in array_lower(_matrix, 2)..array_upper(_matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF NOT nodatamode = 'ignore' THEN
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                IF min > _matrix[x][y] THEN
                    min := _matrix[x][y];
                END IF;
            END LOOP;
        END LOOP;
        RETURN min;
    END;
    $$;


ALTER FUNCTION public.st_min4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_min4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_min4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the minimum pixel value in a neighborhood.';


--
-- Name: st_quantile(text, text, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, quantiles double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_quantile($1, $2, 1, TRUE, 1, $3) $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, quantiles double precision[]) OWNER TO postgres;

--
-- Name: st_quantile(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_quantile($1, $2, 1, TRUE, 1, ARRAY[$3]::double precision[])).value $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, quantile double precision) OWNER TO postgres;

--
-- Name: st_quantile(text, text, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, exclude_nodata_value boolean, quantile double precision DEFAULT NULL::double precision) RETURNS double precision
    LANGUAGE sql STABLE
    AS $_$ SELECT (_st_quantile($1, $2, 1, $3, 1, ARRAY[$4]::double precision[])).value $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, exclude_nodata_value boolean, quantile double precision) OWNER TO postgres;

--
-- Name: st_quantile(text, text, integer, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, quantiles double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_quantile($1, $2, $3, TRUE, 1, $4) $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, quantiles double precision[]) OWNER TO postgres;

--
-- Name: FUNCTION st_quantile(rastertable text, rastercolumn text, nband integer, quantiles double precision[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, quantiles double precision[]) IS 'args: rastertable, rastercolumn, nband, quantiles - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';


--
-- Name: st_quantile(text, text, integer, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_quantile($1, $2, $3, TRUE, 1, ARRAY[$4]::double precision[])).value $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, quantile double precision) OWNER TO postgres;

--
-- Name: st_quantile(text, text, integer, boolean, double precision[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, quantiles double precision[] DEFAULT NULL::double precision[]) RETURNS SETOF public.quantile
    LANGUAGE sql STABLE
    AS $_$ SELECT _st_quantile($1, $2, $3, $4, 1, $5) $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, quantiles double precision[]) OWNER TO postgres;

--
-- Name: FUNCTION st_quantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, quantiles double precision[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, quantiles double precision[]) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true, quantiles=NULL - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';


--
-- Name: st_quantile(text, text, integer, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, quantile double precision) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_quantile($1, $2, $3, $4, 1, ARRAY[$5]::double precision[])).value $_$;


ALTER FUNCTION public.st_quantile(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, quantile double precision) OWNER TO postgres;

--
-- Name: st_range4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_range4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        _matrix float[][];
        min float;
        max float;
    BEGIN
        _matrix := matrix;
        min := 'Infinity'::float;
        max := '-Infinity'::float;
        FOR x in array_lower(matrix, 1)..array_upper(matrix, 1) LOOP
            FOR y in array_lower(matrix, 2)..array_upper(matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF NOT nodatamode = 'ignore' THEN
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                IF min > _matrix[x][y] THEN
                    min = _matrix[x][y];
                END IF;
                IF max < _matrix[x][y] THEN
                    max = _matrix[x][y];
                END IF;
            END LOOP;
        END LOOP;
        IF max = '-Infinity'::float OR min = 'Infinity'::float THEN
            RETURN NULL;
        END IF;
        RETURN max - min;
    END;
    $$;


ALTER FUNCTION public.st_range4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_range4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_range4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the range of pixel values in a neighborhood.';


--
-- Name: st_samealignment(double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_samealignment(ulx1 double precision, uly1 double precision, scalex1 double precision, scaley1 double precision, skewx1 double precision, skewy1 double precision, ulx2 double precision, uly2 double precision, scalex2 double precision, scaley2 double precision, skewx2 double precision, skewy2 double precision) RETURNS boolean
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT st_samealignment(st_makeemptyraster(1, 1, $1, $2, $3, $4, $5, $6), st_makeemptyraster(1, 1, $7, $8, $9, $10, $11, $12)) $_$;


ALTER FUNCTION public.st_samealignment(ulx1 double precision, uly1 double precision, scalex1 double precision, scaley1 double precision, skewx1 double precision, skewy1 double precision, ulx2 double precision, uly2 double precision, scalex2 double precision, scaley2 double precision, skewx2 double precision, skewy2 double precision) OWNER TO postgres;

--
-- Name: FUNCTION st_samealignment(ulx1 double precision, uly1 double precision, scalex1 double precision, scaley1 double precision, skewx1 double precision, skewy1 double precision, ulx2 double precision, uly2 double precision, scalex2 double precision, scaley2 double precision, skewx2 double precision, skewy2 double precision); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_samealignment(ulx1 double precision, uly1 double precision, scalex1 double precision, scaley1 double precision, skewx1 double precision, skewy1 double precision, ulx2 double precision, uly2 double precision, scalex2 double precision, scaley2 double precision, skewx2 double precision, skewy2 double precision) IS 'args: ulx1, uly1, scalex1, scaley1, skewx1, skewy1, ulx2, uly2, scalex2, scaley2, skewx2, skewy2 - Returns true if rasters have same skew, scale, spatial ref and false if they dont with notice detailing issue.';


--
-- Name: st_stddev4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_stddev4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT stddev(unnest) FROM unnest($1) $_$;


ALTER FUNCTION public.st_stddev4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_stddev4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_stddev4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the standard deviation of pixel values in a neighborhood.';


--
-- Name: st_sum4ma(double precision[], text, text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_sum4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    DECLARE
        _matrix float[][];
        sum float;
    BEGIN
        _matrix := matrix;
        sum := 0;
        FOR x in array_lower(matrix, 1)..array_upper(matrix, 1) LOOP
            FOR y in array_lower(matrix, 2)..array_upper(matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF nodatamode = 'ignore' THEN
                        _matrix[x][y] := 0;
                    ELSE
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                sum := sum + _matrix[x][y];
            END LOOP;
        END LOOP;
        RETURN sum;
    END;
    $$;


ALTER FUNCTION public.st_sum4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) OWNER TO postgres;

--
-- Name: FUNCTION st_sum4ma(matrix double precision[], nodatamode text, VARIADIC args text[]); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_sum4ma(matrix double precision[], nodatamode text, VARIADIC args text[]) IS 'args: matrix, nodatamode, VARIADIC args - Raster processing function that calculates the sum of all pixel values in a neighborhood.';


--
-- Name: st_summarystats(text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_summarystats(rastertable text, rastercolumn text, exclude_nodata_value boolean) RETURNS public.summarystats
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_summarystats($1, $2, 1, $3, 1) $_$;


ALTER FUNCTION public.st_summarystats(rastertable text, rastercolumn text, exclude_nodata_value boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_summarystats(rastertable text, rastercolumn text, exclude_nodata_value boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_summarystats(rastertable text, rastercolumn text, exclude_nodata_value boolean) IS 'args: rastertable, rastercolumn, exclude_nodata_value - Returns summary stats consisting of count,sum,mean,stddev,min,max for a given raster band of a raster or raster coverage. Band 1 is assumed is no band is specified.';


--
-- Name: st_summarystats(text, text, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_summarystats(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true) RETURNS public.summarystats
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT _st_summarystats($1, $2, $3, $4, 1) $_$;


ALTER FUNCTION public.st_summarystats(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean) OWNER TO postgres;

--
-- Name: FUNCTION st_summarystats(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_summarystats(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true - Returns summary stats consisting of count,sum,mean,stddev,min,max for a given raster band of a raster or raster coverage. Band 1 is assumed is no band is specified.';


--
-- Name: st_valuecount(text, text, double precision[], double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuecount(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $_$ SELECT value, count FROM _st_valuecount($1, $2, 1, TRUE, $3, $4) $_$;


ALTER FUNCTION public.st_valuecount(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer) OWNER TO postgres;

--
-- Name: FUNCTION st_valuecount(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_valuecount(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer) IS 'args: rastertable, rastercolumn, searchvalues, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';


--
-- Name: st_valuecount(text, text, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuecount(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision DEFAULT 0) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_valuecount($1, $2, 1, TRUE, ARRAY[$3]::double precision[], $4)).count $_$;


ALTER FUNCTION public.st_valuecount(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision) OWNER TO postgres;

--
-- Name: FUNCTION st_valuecount(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_valuecount(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision) IS 'args: rastertable, rastercolumn, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';


--
-- Name: st_valuecount(text, text, integer, double precision[], double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $_$ SELECT value, count FROM _st_valuecount($1, $2, $3, TRUE, $4, $5) $_$;


ALTER FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer) OWNER TO postgres;

--
-- Name: FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer) IS 'args: rastertable, rastercolumn, nband, searchvalues, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';


--
-- Name: st_valuecount(text, text, integer, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision DEFAULT 0) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_valuecount($1, $2, $3, TRUE, ARRAY[$4]::double precision[], $5)).count $_$;


ALTER FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision) OWNER TO postgres;

--
-- Name: FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision) IS 'args: rastertable, rastercolumn, nband, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';


--
-- Name: st_valuecount(text, text, integer, boolean, double precision[], double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, searchvalues double precision[] DEFAULT NULL::double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $_$ SELECT value, count FROM _st_valuecount($1, $2, $3, $4, $5, $6) $_$;


ALTER FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer) OWNER TO postgres;

--
-- Name: FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalues double precision[], roundto double precision, OUT value double precision, OUT count integer) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true, searchvalues=NULL, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';


--
-- Name: st_valuecount(text, text, integer, boolean, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision DEFAULT 0) RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_valuecount($1, $2, $3, $4, ARRAY[$5]::double precision[], $6)).count $_$;


ALTER FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision) OWNER TO postgres;

--
-- Name: FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision) IS 'args: rastertable, rastercolumn, nband, exclude_nodata_value, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';


--
-- Name: st_valuepercent(text, text, double precision[], double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $_$ SELECT value, percent FROM _st_valuecount($1, $2, 1, TRUE, $3, $4) $_$;


ALTER FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision, OUT value double precision, OUT percent double precision) OWNER TO postgres;

--
-- Name: st_valuepercent(text, text, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision DEFAULT 0) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_valuecount($1, $2, 1, TRUE, ARRAY[$3]::double precision[], $4)).percent $_$;


ALTER FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision) OWNER TO postgres;

--
-- Name: st_valuepercent(text, text, integer, double precision[], double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $_$ SELECT value, percent FROM _st_valuecount($1, $2, $3, TRUE, $4, $5) $_$;


ALTER FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision, OUT value double precision, OUT percent double precision) OWNER TO postgres;

--
-- Name: st_valuepercent(text, text, integer, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision DEFAULT 0) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_valuecount($1, $2, $3, TRUE, ARRAY[$4]::double precision[], $5)).percent $_$;


ALTER FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision) OWNER TO postgres;

--
-- Name: st_valuepercent(text, text, integer, boolean, double precision[], double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT true, searchvalues double precision[] DEFAULT NULL::double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision) RETURNS SETOF record
    LANGUAGE sql STABLE
    AS $_$ SELECT value, percent FROM _st_valuecount($1, $2, $3, $4, $5, $6) $_$;


ALTER FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalues double precision[], roundto double precision, OUT value double precision, OUT percent double precision) OWNER TO postgres;

--
-- Name: st_valuepercent(text, text, integer, boolean, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision DEFAULT 0) RETURNS double precision
    LANGUAGE sql STABLE STRICT
    AS $_$ SELECT (_st_valuecount($1, $2, $3, $4, ARRAY[$5]::double precision[], $6)).percent $_$;


ALTER FUNCTION public.st_valuepercent(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision) OWNER TO postgres;

--
-- Name: unlockrows(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.unlockrows(text) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $_$ 
DECLARE
	ret int;
BEGIN

	IF NOT LongTransactionsEnabled() THEN
		RAISE EXCEPTION 'Long transaction support disabled, use EnableLongTransaction() to enable.';
	END IF;

	EXECUTE 'DELETE FROM authorization_table where authid = ' ||
		quote_literal($1);

	GET DIAGNOSTICS ret = ROW_COUNT;

	RETURN ret;
END;
$_$;


ALTER FUNCTION public.unlockrows(text) OWNER TO postgres;

--
-- Name: updategeometrysrid(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updategeometrysrid(character varying, character varying, integer) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
	ret  text;
BEGIN
	SELECT UpdateGeometrySRID('','',$1,$2,$3) into ret;
	RETURN ret;
END;
$_$;


ALTER FUNCTION public.updategeometrysrid(character varying, character varying, integer) OWNER TO postgres;

--
-- Name: updategeometrysrid(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updategeometrysrid(character varying, character varying, character varying, integer) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
	ret  text;
BEGIN
	SELECT UpdateGeometrySRID('',$1,$2,$3,$4) into ret;
	RETURN ret;
END;
$_$;


ALTER FUNCTION public.updategeometrysrid(character varying, character varying, character varying, integer) OWNER TO postgres;

--
-- Name: updategeometrysrid(character varying, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updategeometrysrid(catalogn_name character varying, schema_name character varying, table_name character varying, column_name character varying, new_srid_in integer) RETURNS text
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
	myrec RECORD;
	okay boolean;
	cname varchar;
	real_schema name;
	unknown_srid integer;
	new_srid integer := new_srid_in;

BEGIN


	-- Find, check or fix schema_name
	IF ( schema_name != '' ) THEN
		okay = false;

		FOR myrec IN SELECT nspname FROM pg_namespace WHERE text(nspname) = schema_name LOOP
			okay := true;
		END LOOP;

		IF ( okay <> true ) THEN
			RAISE EXCEPTION 'Invalid schema name';
		ELSE
			real_schema = schema_name;
		END IF;
	ELSE
		SELECT INTO real_schema current_schema()::text;
	END IF;

	-- Ensure that column_name is in geometry_columns
	okay = false;
	FOR myrec IN SELECT type, coord_dimension FROM geometry_columns WHERE f_table_schema = text(real_schema) and f_table_name = table_name and f_geometry_column = column_name LOOP
		okay := true;
	END LOOP;
	IF (NOT okay) THEN
		RAISE EXCEPTION 'column not found in geometry_columns table';
		RETURN false;
	END IF;

	-- Ensure that new_srid is valid
	IF ( new_srid > 0 ) THEN
		IF ( SELECT count(*) = 0 from spatial_ref_sys where srid = new_srid ) THEN
			RAISE EXCEPTION 'invalid SRID: % not found in spatial_ref_sys', new_srid;
			RETURN false;
		END IF;
	ELSE
		unknown_srid := ST_SRID('POINT EMPTY'::geometry);
		IF ( new_srid != unknown_srid ) THEN
			new_srid := unknown_srid;
			RAISE NOTICE 'SRID value % converted to the officially unknown SRID value %', new_srid_in, new_srid;
		END IF;
	END IF;

	IF postgis_constraint_srid(schema_name, table_name, column_name) IS NOT NULL THEN 
	-- srid was enforced with constraints before, keep it that way.
        -- Make up constraint name
        cname = 'enforce_srid_'  || column_name;
    
        -- Drop enforce_srid constraint
        EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) ||
            '.' || quote_ident(table_name) ||
            ' DROP constraint ' || quote_ident(cname);
    
        -- Update geometries SRID
        EXECUTE 'UPDATE ' || quote_ident(real_schema) ||
            '.' || quote_ident(table_name) ||
            ' SET ' || quote_ident(column_name) ||
            ' = ST_SetSRID(' || quote_ident(column_name) ||
            ', ' || new_srid::text || ')';
            
        -- Reset enforce_srid constraint
        EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) ||
            '.' || quote_ident(table_name) ||
            ' ADD constraint ' || quote_ident(cname) ||
            ' CHECK (st_srid(' || quote_ident(column_name) ||
            ') = ' || new_srid::text || ')';
    ELSE 
        -- We will use typmod to enforce if no srid constraints
        -- We are using postgis_type_name to lookup the new name 
        -- (in case Paul changes his mind and flips geometry_columns to return old upper case name) 
        EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) || '.' || quote_ident(table_name) || 
        ' ALTER COLUMN ' || quote_ident(column_name) || ' TYPE  geometry(' || postgis_type_name(myrec.type, myrec.coord_dimension, true) || ', ' || new_srid::text || ') USING ST_SetSRID(' || quote_ident(column_name) || ',' || new_srid::text || ');' ;
    END IF;

	RETURN real_schema || '.' || table_name || '.' || column_name ||' SRID changed to ' || new_srid::text;

END;
$$;


ALTER FUNCTION public.updategeometrysrid(catalogn_name character varying, schema_name character varying, table_name character varying, column_name character varying, new_srid_in integer) OWNER TO postgres;

--
-- Name: btree_geography_ops; Type: OPERATOR FAMILY; Schema: public; Owner: postgres
--

CREATE OPERATOR FAMILY public.btree_geography_ops USING btree;


ALTER OPERATOR FAMILY public.btree_geography_ops USING btree OWNER TO postgres;

--
-- Name: btree_geometry_ops; Type: OPERATOR FAMILY; Schema: public; Owner: postgres
--

CREATE OPERATOR FAMILY public.btree_geometry_ops USING btree;


ALTER OPERATOR FAMILY public.btree_geometry_ops USING btree OWNER TO postgres;

--
-- Name: gist_geography_ops; Type: OPERATOR FAMILY; Schema: public; Owner: postgres
--

CREATE OPERATOR FAMILY public.gist_geography_ops USING gist;


ALTER OPERATOR FAMILY public.gist_geography_ops USING gist OWNER TO postgres;

--
-- Name: gist_geometry_ops_2d; Type: OPERATOR FAMILY; Schema: public; Owner: postgres
--

CREATE OPERATOR FAMILY public.gist_geometry_ops_2d USING gist;


ALTER OPERATOR FAMILY public.gist_geometry_ops_2d USING gist OWNER TO postgres;

--
-- Name: gist_geometry_ops_nd; Type: OPERATOR FAMILY; Schema: public; Owner: postgres
--

CREATE OPERATOR FAMILY public.gist_geometry_ops_nd USING gist;


ALTER OPERATOR FAMILY public.gist_geometry_ops_nd USING gist OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: a; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.a (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.a OWNER TO postgres;

--
-- Name: abc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.abc (
    emp_dept integer,
    emp_idno integer,
    rnk2 bigint
);


ALTER TABLE public.abc OWNER TO postgres;

--
-- Name: actor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor (
    act_id integer NOT NULL,
    act_fname character(20),
    act_lname character(20),
    act_gender character(1)
);


ALTER TABLE public.actor OWNER TO postgres;

--
-- Name: actorsbackup2017; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actorsbackup2017 (
    act_fname character(20),
    act_lname character(20)
);


ALTER TABLE public.actorsbackup2017 OWNER TO postgres;

--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.address (
    city character varying(15)
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: affiliated_with; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.affiliated_with (
    physician integer NOT NULL,
    department integer NOT NULL,
    primaryaffiliation boolean NOT NULL
);


ALTER TABLE public.affiliated_with OWNER TO postgres;

--
-- Name: customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer (
    customer_id numeric(5,0) NOT NULL,
    cust_name character varying(30) NOT NULL,
    city character varying(15),
    grade numeric(3,0) DEFAULT 0,
    salesman_id numeric(5,0) NOT NULL
);


ALTER TABLE public.customer OWNER TO postgres;

--
-- Name: agentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.agentview AS
 SELECT customer.customer_id,
    customer.cust_name,
    customer.city,
    customer.grade,
    customer.salesman_id
   FROM public.customer;


ALTER TABLE public.agentview OWNER TO postgres;

--
-- Name: ahmed; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ahmed (
    employee_id numeric(6,0),
    department_id numeric(4,0),
    salary numeric(8,2)
);


ALTER TABLE public.ahmed OWNER TO postgres;

--
-- Name: appointment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointment (
    appointmentid integer NOT NULL,
    patient integer NOT NULL,
    prepnurse integer,
    physician integer NOT NULL,
    start_dt_time timestamp without time zone NOT NULL,
    end_dt_time timestamp without time zone NOT NULL,
    examinationroom text NOT NULL
);


ALTER TABLE public.appointment OWNER TO postgres;

--
-- Name: asst_referee_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asst_referee_mast (
    ass_ref_id numeric NOT NULL,
    ass_ref_name character varying(40) NOT NULL,
    country_id numeric NOT NULL
);


ALTER TABLE public.asst_referee_mast OWNER TO postgres;

--
-- Name: bh; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bh (
    name character varying(20) NOT NULL,
    emp_id integer NOT NULL,
    process character varying(20)
);


ALTER TABLE public.bh OWNER TO postgres;

--
-- Name: bitch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bitch (
    sum bigint
);


ALTER TABLE public.bitch OWNER TO postgres;

--
-- Name: blah; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blah (
    ord_no numeric(5,0),
    purch_amt numeric(8,2),
    ord_date date,
    customer_id numeric(5,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.blah OWNER TO postgres;

--
-- Name: block; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.block (
    blockfloor integer NOT NULL,
    blockcode integer NOT NULL
);


ALTER TABLE public.block OWNER TO postgres;

--
-- Name: casino; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.casino (
    pricerange numeric(6,0) NOT NULL,
    events character varying(50),
    location character varying(40) NOT NULL,
    casino character varying(75) NOT NULL
);


ALTER TABLE public.casino OWNER TO postgres;

--
-- Name: coach_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coach_mast (
    coach_id numeric NOT NULL,
    coach_name character varying(40) NOT NULL
);


ALTER TABLE public.coach_mast OWNER TO postgres;

--
-- Name: col1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.col1 (
    "?column?" integer
);


ALTER TABLE public.col1 OWNER TO postgres;

--
-- Name: company_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.company_mast (
    com_id integer NOT NULL,
    com_name character varying(20) NOT NULL
);


ALTER TABLE public.company_mast OWNER TO postgres;

--
-- Name: countries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.countries (
    country_id character varying(2),
    country_name character varying(40),
    region_id numeric(10,0)
);


ALTER TABLE public.countries OWNER TO postgres;

--
-- Name: customer_backup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer_backup (
    customer_id numeric(5,0),
    cust_name character varying(30),
    city character varying(15),
    grade numeric(3,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.customer_backup OWNER TO postgres;

--
-- Name: customer_id; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer_id (
    ord_no numeric(5,0),
    purch_amt numeric(8,2),
    ord_date date,
    customer_id numeric(5,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.customer_id OWNER TO postgres;

--
-- Name: customer_id_123; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customer_id_123 (
    ord_no numeric(5,0),
    purch_amt numeric(8,2),
    ord_date date,
    customer_id numeric(5,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.customer_id_123 OWNER TO postgres;

--
-- Name: customergradelevels; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.customergradelevels AS
 SELECT DISTINCT customer.grade,
    count(*) AS count
   FROM public.customer
  GROUP BY customer.grade;


ALTER TABLE public.customergradelevels OWNER TO postgres;

--
-- Name: customergradelevels2; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.customergradelevels2 AS
 SELECT DISTINCT customer.grade,
    count(*) AS count
   FROM public.customer
  WHERE (customer.grade IS NOT NULL)
  GROUP BY customer.grade;


ALTER TABLE public.customergradelevels2 OWNER TO postgres;

--
-- Name: department; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department (
    departmentid integer NOT NULL,
    name text NOT NULL,
    head integer NOT NULL
);


ALTER TABLE public.department OWNER TO postgres;

--
-- Name: department_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.department_detail (
    first_name character varying(20),
    last_name character varying(25),
    department_id numeric(4,0),
    department_name character varying(30)
);


ALTER TABLE public.department_detail OWNER TO postgres;

--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.departments (
    department_id numeric(4,0) NOT NULL,
    department_name character varying(30) NOT NULL,
    manager_id numeric(6,0) DEFAULT NULL::numeric,
    location_id numeric(4,0) DEFAULT NULL::numeric
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: director; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.director (
    dir_id integer NOT NULL,
    dir_fname character(20),
    dir_lname character(20)
);


ALTER TABLE public.director OWNER TO postgres;

--
-- Name: duplicate; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.duplicate (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.duplicate OWNER TO postgres;

--
-- Name: elephants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.elephants (
    id integer NOT NULL,
    name text,
    date date DEFAULT now()
);


ALTER TABLE public.elephants OWNER TO postgres;

--
-- Name: emp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emp (
    ename character varying(13),
    salary numeric(6,0),
    eid numeric(3,0) NOT NULL
);


ALTER TABLE public.emp OWNER TO postgres;

--
-- Name: emp_department; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emp_department (
    dpt_code integer NOT NULL,
    dpt_name character(15) NOT NULL,
    dpt_allotment integer NOT NULL
);


ALTER TABLE public.emp_department OWNER TO postgres;

--
-- Name: emp_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emp_details (
    emp_idno integer NOT NULL,
    emp_fname character(15) NOT NULL,
    emp_lname character(15) NOT NULL,
    emp_dept integer NOT NULL
);


ALTER TABLE public.emp_details OWNER TO postgres;

--
-- Name: employee; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee (
    empno integer,
    ename character varying(20)
);


ALTER TABLE public.employee OWNER TO postgres;

--
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employees (
    employee_id numeric(6,0) DEFAULT (0)::numeric NOT NULL,
    first_name character varying(20) DEFAULT NULL::character varying,
    last_name character varying(25) NOT NULL,
    email character varying(25) NOT NULL,
    phone_number character varying(20) DEFAULT NULL::character varying,
    hire_date date NOT NULL,
    job_id character varying(10) NOT NULL,
    salary numeric(8,2) DEFAULT NULL::numeric,
    commission_pct numeric(2,2) DEFAULT NULL::numeric,
    manager_id numeric(6,0) DEFAULT NULL::numeric,
    department_id numeric(4,0) DEFAULT NULL::numeric
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- Name: ff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ff (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2),
    year integer,
    subject character(25),
    winner character(45),
    country character(25),
    category character(25)
);


ALTER TABLE public.ff OWNER TO postgres;

--
-- Name: fg; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fg (
    customer_id numeric(5,0),
    avg numeric
);


ALTER TABLE public.fg OWNER TO postgres;

--
-- Name: game_scores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.game_scores (
    id integer NOT NULL,
    name text,
    score integer
);


ALTER TABLE public.game_scores OWNER TO postgres;

--
-- Name: genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.genres (
    gen_id integer NOT NULL,
    gen_title character(20)
);


ALTER TABLE public.genres OWNER TO postgres;

--
-- Name: goal_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goal_details (
    goal_id numeric NOT NULL,
    match_no numeric NOT NULL,
    player_id numeric NOT NULL,
    team_id numeric NOT NULL,
    goal_time numeric NOT NULL,
    goal_type character(1) NOT NULL,
    play_stage character(1) NOT NULL,
    goal_schedule character(2) NOT NULL,
    goal_half numeric
);


ALTER TABLE public.goal_details OWNER TO postgres;

--
-- Name: grade; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grade (
    city character varying(15)
);


ALTER TABLE public.grade OWNER TO postgres;

--
-- Name: grade_customer; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.grade_customer AS
 SELECT customer.grade,
    count(customer.customer_id) AS count
   FROM public.customer
  GROUP BY customer.grade;


ALTER TABLE public.grade_customer OWNER TO postgres;

--
-- Name: grade_customer1; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.grade_customer1 AS
 SELECT customer.grade,
    count(*) AS number
   FROM public.customer
  GROUP BY customer.grade;


ALTER TABLE public.grade_customer1 OWNER TO postgres;

--
-- Name: grades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.grades (
    id integer NOT NULL,
    grade_1 integer,
    grade_2 integer,
    grade_3 integer
);


ALTER TABLE public.grades OWNER TO postgres;

--
-- Name: hello; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hello (
    number_one integer,
    number_two integer,
    number_three integer
);


ALTER TABLE public.hello OWNER TO postgres;

--
-- Name: hello1_1122; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hello1_1122 (
    abc integer
);


ALTER TABLE public.hello1_1122 OWNER TO postgres;

--
-- Name: hello1_12; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hello1_12 (
    abc integer
);


ALTER TABLE public.hello1_12 OWNER TO postgres;

--
-- Name: hello_12; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hello_12 (
    abc integer
);


ALTER TABLE public.hello_12 OWNER TO postgres;

--
-- Name: item_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.item_mast (
    pro_id integer NOT NULL,
    pro_name character varying(25) NOT NULL,
    pro_price numeric(8,2) NOT NULL,
    pro_com integer NOT NULL
);


ALTER TABLE public.item_mast OWNER TO postgres;

--
-- Name: job_grades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_grades (
    grade_level character varying(20) NOT NULL,
    lowest_sal numeric(5,0) NOT NULL,
    highest_sal numeric(5,0) NOT NULL
);


ALTER TABLE public.job_grades OWNER TO postgres;

--
-- Name: job_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_history (
    employee_id numeric(6,0) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    job_id character varying(10) NOT NULL,
    department_id numeric(4,0) DEFAULT NULL::numeric
);


ALTER TABLE public.job_history OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    job_id character varying(10) DEFAULT ''::character varying NOT NULL,
    job_title character varying(35) NOT NULL,
    min_salary numeric(6,0) DEFAULT NULL::numeric,
    max_salary numeric(6,0) DEFAULT NULL::numeric
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- Name: kk; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kk (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.kk OWNER TO postgres;

--
-- Name: kkk; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kkk (
    name character varying(30)
);


ALTER TABLE public.kkk OWNER TO postgres;

--
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    location_id numeric(4,0) DEFAULT (0)::numeric NOT NULL,
    street_address character varying(40) DEFAULT NULL::character varying,
    postal_code character varying(12) DEFAULT NULL::character varying,
    city character varying(30) NOT NULL,
    state_province character varying(25) DEFAULT NULL::character varying,
    country_id character varying(2) DEFAULT NULL::character varying
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- Name: londoncustomers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.londoncustomers (
    cust_name character varying(30),
    city character varying(15)
);


ALTER TABLE public.londoncustomers OWNER TO postgres;

--
-- Name: manufacturers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.manufacturers (
    code integer NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.manufacturers OWNER TO postgres;

--
-- Name: match_captain; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.match_captain (
    match_no numeric NOT NULL,
    team_id numeric NOT NULL,
    player_captain numeric NOT NULL
);


ALTER TABLE public.match_captain OWNER TO postgres;

--
-- Name: match_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.match_details (
    match_no numeric NOT NULL,
    play_stage character(1) NOT NULL,
    team_id numeric NOT NULL,
    win_lose character(1) NOT NULL,
    decided_by character(1) NOT NULL,
    goal_score numeric NOT NULL,
    penalty_score numeric,
    ass_ref numeric NOT NULL,
    player_gk numeric NOT NULL
);


ALTER TABLE public.match_details OWNER TO postgres;

--
-- Name: match_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.match_mast (
    match_no numeric NOT NULL,
    play_stage character(1) NOT NULL,
    play_date date NOT NULL,
    results character(5) NOT NULL,
    decided_by character(1) NOT NULL,
    goal_score character(5) NOT NULL,
    venue_id numeric NOT NULL,
    referee_id numeric NOT NULL,
    audence numeric NOT NULL,
    plr_of_match numeric NOT NULL,
    stop1_sec numeric NOT NULL,
    stop2_sec numeric NOT NULL
);


ALTER TABLE public.match_mast OWNER TO postgres;

--
-- Name: maxim00; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maxim00 (
    num integer,
    name character varying(10)
);


ALTER TABLE public.maxim00 OWNER TO postgres;

--
-- Name: maximum; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maximum (
    num integer,
    name character varying(10)
);


ALTER TABLE public.maximum OWNER TO postgres;

--
-- Name: maximum00; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maximum00 (
    num integer,
    name character varying(10)
);


ALTER TABLE public.maximum00 OWNER TO postgres;

--
-- Name: maximum899; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.maximum899 (
    num integer,
    name character varying(10)
);


ALTER TABLE public.maximum899 OWNER TO postgres;

--
-- Name: medication; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medication (
    code integer NOT NULL,
    name text NOT NULL,
    brand text NOT NULL,
    description text NOT NULL
);


ALTER TABLE public.medication OWNER TO postgres;

--
-- Name: movie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movie (
    mov_id integer NOT NULL,
    mov_title character(50),
    mov_year integer,
    mov_time integer,
    mov_lang character(15),
    mov_dt_rel date,
    mov_rel_country character(5)
);


ALTER TABLE public.movie OWNER TO postgres;

--
-- Name: movie_cast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movie_cast (
    act_id integer NOT NULL,
    mov_id integer NOT NULL,
    role character(30)
);


ALTER TABLE public.movie_cast OWNER TO postgres;

--
-- Name: movie_direction; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movie_direction (
    dir_id integer NOT NULL,
    mov_id integer NOT NULL
);


ALTER TABLE public.movie_direction OWNER TO postgres;

--
-- Name: movie_genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movie_genres (
    mov_id integer NOT NULL,
    gen_id integer NOT NULL
);


ALTER TABLE public.movie_genres OWNER TO postgres;

--
-- Name: my; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.my (
    customer_id numeric(5,0),
    avg numeric
);


ALTER TABLE public.my OWNER TO postgres;

--
-- Name: mytemptable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mytemptable (
    customer_id numeric(5,0),
    avg numeric
);


ALTER TABLE public.mytemptable OWNER TO postgres;

--
-- Name: mytest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mytest (
    ord_num numeric(6,0) NOT NULL,
    ord_amount numeric(12,2),
    ord_date date NOT NULL,
    cust_code character(6) NOT NULL,
    agent_code character(6) NOT NULL
);


ALTER TABLE public.mytest OWNER TO postgres;

--
-- Name: mytest1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mytest1 (
    ord_num numeric(6,0) NOT NULL,
    ord_amount numeric(12,2),
    ord_date date NOT NULL,
    cust_code character(6) NOT NULL,
    agent_code character(6) NOT NULL
);


ALTER TABLE public.mytest1 OWNER TO postgres;

--
-- Name: salesman; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salesman (
    salesman_id numeric(5,0) NOT NULL,
    name character varying(30) NOT NULL,
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.salesman OWNER TO postgres;

--
-- Name: myworkstuff; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.myworkstuff AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman;


ALTER TABLE public.myworkstuff OWNER TO postgres;

--
-- Name: myworkstuffs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.myworkstuffs AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman
  WHERE ((salesman.city)::text = 'New York'::text);


ALTER TABLE public.myworkstuffs OWNER TO postgres;

--
-- Name: new; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.new (
    city character varying(15)
);


ALTER TABLE public.new OWNER TO postgres;

--
-- Name: new123; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.new123 (
    "Customer" character varying(30),
    city character varying(15),
    "Salesman" character varying(30),
    commission numeric(5,2)
);


ALTER TABLE public.new123 OWNER TO postgres;

--
-- Name: new_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.new_table (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.new_table OWNER TO postgres;

--
-- Name: newsalesman; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.newsalesman (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.newsalesman OWNER TO postgres;

--
-- Name: newtab; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.newtab (
    ord_no numeric(5,0),
    purch_amt numeric(8,2),
    ord_date date,
    customer_id numeric(5,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.newtab OWNER TO postgres;

--
-- Name: newtable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.newtable (
    roomnumber integer,
    roomtype character varying(30),
    blockfloor integer,
    blockcode integer,
    unavailable boolean
);


ALTER TABLE public.newtable OWNER TO postgres;

--
-- Name: newyorksalesman; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.newyorksalesman AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city,
    salesman.commission
   FROM public.salesman
  WHERE ((salesman.city)::text = 'new york'::text);


ALTER TABLE public.newyorksalesman OWNER TO postgres;

--
-- Name: newyorksalesman2; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.newyorksalesman2 AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city,
    salesman.commission
   FROM public.salesman
  WHERE ((salesman.city)::text = 'rome'::text);


ALTER TABLE public.newyorksalesman2 OWNER TO postgres;

--
-- Name: newyorksalesman3; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.newyorksalesman3 AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city,
    salesman.commission
   FROM public.salesman
  WHERE ((salesman.city)::text = 'Rome'::text);


ALTER TABLE public.newyorksalesman3 OWNER TO postgres;

--
-- Name: newyorkstaff; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.newyorkstaff AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city,
    salesman.commission
   FROM public.salesman
  WHERE ((salesman.city)::text = 'New York'::text);


ALTER TABLE public.newyorkstaff OWNER TO postgres;

--
-- Name: nobel_win; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nobel_win (
    year integer,
    subject character(25),
    winner character(45),
    country character(25),
    category character(25)
);


ALTER TABLE public.nobel_win OWNER TO postgres;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    ord_no numeric(5,0) NOT NULL,
    purch_amt numeric(8,2) DEFAULT 0,
    ord_date date,
    customer_id numeric(5,0) NOT NULL,
    salesman_id numeric(5,0) NOT NULL
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: norders; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.norders AS
 SELECT salesman.name,
    avg(orders.purch_amt) AS avg,
    sum(orders.purch_amt) AS sum
   FROM public.salesman,
    public.orders
  WHERE (salesman.salesman_id = orders.salesman_id)
  GROUP BY salesman.name;


ALTER TABLE public.norders OWNER TO postgres;

--
-- Name: nros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nros (
    uno integer,
    dos integer
);


ALTER TABLE public.nros OWNER TO postgres;

--
-- Name: nuevo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nuevo (
    city character varying(15)
);


ALTER TABLE public.nuevo OWNER TO postgres;

--
-- Name: numbers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.numbers (
    one integer,
    two integer,
    three integer
);


ALTER TABLE public.numbers OWNER TO postgres;

--
-- Name: numeri; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.numeri (
    id integer,
    data date,
    decimali real
);


ALTER TABLE public.numeri OWNER TO postgres;

--
-- Name: numeros; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.numeros (
    uno integer,
    dos integer
);


ALTER TABLE public.numeros OWNER TO postgres;

--
-- Name: nurse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nurse (
    employeeid integer NOT NULL,
    name text NOT NULL,
    "position" text NOT NULL,
    registered boolean NOT NULL,
    ssn integer NOT NULL
);


ALTER TABLE public.nurse OWNER TO postgres;

--
-- Name: odr; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.odr AS
 SELECT orders.ord_no
   FROM public.orders
  WHERE ((orders.ord_no >= (70002)::numeric) AND (orders.ord_no <= (70008)::numeric));


ALTER TABLE public.odr OWNER TO postgres;

--
-- Name: oi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.oi (
    customer_id numeric(5,0),
    avg numeric
);


ALTER TABLE public.oi OWNER TO postgres;

--
-- Name: on_call; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.on_call (
    nurse integer NOT NULL,
    blockfloor integer NOT NULL,
    blockcode integer NOT NULL,
    oncallstart timestamp without time zone NOT NULL,
    oncallend timestamp without time zone NOT NULL
);


ALTER TABLE public.on_call OWNER TO postgres;

--
-- Name: ordersview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.ordersview AS
 SELECT orders.ord_no,
    orders.purch_amt
   FROM public.orders
  WHERE (orders.purch_amt < (500)::numeric);


ALTER TABLE public.ordersview OWNER TO postgres;

--
-- Name: orozco; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orozco (
    city character varying(15)
);


ALTER TABLE public.orozco OWNER TO postgres;

--
-- Name: partest1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partest1 (
    ord_num numeric(6,0) NOT NULL,
    ord_amount numeric(12,2),
    ord_date date NOT NULL,
    cust_code character(6) NOT NULL,
    agent_code character(6) NOT NULL
);


ALTER TABLE public.partest1 OWNER TO postgres;

--
-- Name: participant; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.participant (
    participant_id integer NOT NULL,
    part_name character varying(20) NOT NULL
);


ALTER TABLE public.participant OWNER TO postgres;

--
-- Name: participants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.participants (
    participant_id integer NOT NULL,
    part_name character varying(20) NOT NULL
);


ALTER TABLE public.participants OWNER TO postgres;

--
-- Name: patient; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patient (
    ssn integer NOT NULL,
    name text NOT NULL,
    address text NOT NULL,
    phone text NOT NULL,
    insuranceid integer NOT NULL,
    pcp integer NOT NULL
);


ALTER TABLE public.patient OWNER TO postgres;

--
-- Name: penalty_gk; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.penalty_gk (
    match_no numeric NOT NULL,
    team_id numeric NOT NULL,
    player_gk numeric NOT NULL
);


ALTER TABLE public.penalty_gk OWNER TO postgres;

--
-- Name: penalty_shootout; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.penalty_shootout (
    kick_id numeric NOT NULL,
    match_no numeric NOT NULL,
    team_id numeric NOT NULL,
    player_id numeric NOT NULL,
    score_goal character(1) NOT NULL,
    kick_no numeric NOT NULL
);


ALTER TABLE public.penalty_shootout OWNER TO postgres;

--
-- Name: persons; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.persons (
    personid integer,
    lastname character varying(255),
    firstname character varying(255),
    address character varying(255),
    city character varying(255)
);


ALTER TABLE public.persons OWNER TO postgres;

--
-- Name: physician; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.physician (
    employeeid integer NOT NULL,
    name text NOT NULL,
    "position" text NOT NULL,
    ssn integer NOT NULL
);


ALTER TABLE public.physician OWNER TO postgres;

--
-- Name: player_booked; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_booked (
    match_no numeric NOT NULL,
    team_id numeric NOT NULL,
    player_id numeric NOT NULL,
    booking_time numeric NOT NULL,
    sent_off character(1) DEFAULT NULL::bpchar,
    play_schedule character(2) NOT NULL,
    play_half numeric NOT NULL
);


ALTER TABLE public.player_booked OWNER TO postgres;

--
-- Name: player_in_out; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_in_out (
    match_no numeric NOT NULL,
    team_id numeric NOT NULL,
    player_id numeric NOT NULL,
    in_out character(1) NOT NULL,
    time_in_out numeric NOT NULL,
    play_schedule character(2) NOT NULL,
    play_half numeric NOT NULL
);


ALTER TABLE public.player_in_out OWNER TO postgres;

--
-- Name: player_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_mast (
    player_id numeric NOT NULL,
    team_id numeric NOT NULL,
    jersey_no numeric NOT NULL,
    player_name character varying(40) NOT NULL,
    posi_to_play character(2) NOT NULL,
    dt_of_bir date,
    age numeric,
    playing_club character varying(40)
);


ALTER TABLE public.player_mast OWNER TO postgres;

--
-- Name: playing_position; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.playing_position (
    position_id character(2) NOT NULL,
    position_desc character varying(15) NOT NULL
);


ALTER TABLE public.playing_position OWNER TO postgres;

--
-- Name: prescribes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescribes (
    physician integer NOT NULL,
    patient integer NOT NULL,
    medication integer NOT NULL,
    date timestamp without time zone NOT NULL,
    appointment integer,
    dose text NOT NULL
);


ALTER TABLE public.prescribes OWNER TO postgres;

--
-- Name: procedure; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.procedure (
    code integer NOT NULL,
    name text NOT NULL,
    cost real NOT NULL
);


ALTER TABLE public.procedure OWNER TO postgres;

--
-- Name: raster_overviews; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.raster_overviews AS
 SELECT current_database() AS o_table_catalog,
    n.nspname AS o_table_schema,
    c.relname AS o_table_name,
    a.attname AS o_raster_column,
    current_database() AS r_table_catalog,
    (split_part(split_part(s.consrc, '''::name'::text, 1), ''''::text, 2))::name AS r_table_schema,
    (split_part(split_part(s.consrc, '''::name'::text, 2), ''''::text, 2))::name AS r_table_name,
    (split_part(split_part(s.consrc, '''::name'::text, 3), ''''::text, 2))::name AS r_raster_column,
    (btrim(split_part(s.consrc, ','::text, 2)))::integer AS overview_factor
   FROM pg_class c,
    pg_attribute a,
    pg_type t,
    pg_namespace n,
    pg_constraint s
  WHERE ((((((((((t.typname = 'raster'::name) AND (a.attisdropped = false)) AND (a.atttypid = t.oid)) AND (a.attrelid = c.oid)) AND (c.relnamespace = n.oid)) AND ((c.relkind = 'r'::"char") OR (c.relkind = 'v'::"char"))) AND (s.connamespace = n.oid)) AND (s.conrelid = c.oid)) AND (s.consrc ~~ '%_overview_constraint(%'::text)) AND (NOT pg_is_other_temp_schema(c.relnamespace)));


ALTER TABLE public.raster_overviews OWNER TO postgres;

--
-- Name: rating; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rating (
    mov_id integer NOT NULL,
    rev_id integer NOT NULL,
    rev_stars numeric(4,2),
    num_o_ratings integer
);


ALTER TABLE public.rating OWNER TO postgres;

--
-- Name: referee_mast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.referee_mast (
    referee_id numeric NOT NULL,
    referee_name character varying(40) NOT NULL,
    country_id numeric NOT NULL
);


ALTER TABLE public.referee_mast OWNER TO postgres;

--
-- Name: regions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.regions (
    region_id numeric(10,0) NOT NULL,
    region_name character(25)
);


ALTER TABLE public.regions OWNER TO postgres;

--
-- Name: related; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.related (
    city character varying(15)
);


ALTER TABLE public.related OWNER TO postgres;

--
-- Name: reviewer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reviewer (
    rev_id integer NOT NULL,
    rev_name character(30)
);


ALTER TABLE public.reviewer OWNER TO postgres;

--
-- Name: rightjoins; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.rightjoins AS
 SELECT t1.customer_id,
    t1.grade,
    t2.salesman_id
   FROM (public.customer t1
     RIGHT JOIN public.orders t2 ON ((t1.customer_id = t2.customer_id)))
  WHERE (t1.grade IS NOT NULL)
  ORDER BY t1.customer_id;


ALTER TABLE public.rightjoins OWNER TO postgres;

--
-- Name: room; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.room (
    roomnumber integer NOT NULL,
    roomtype character varying(30) NOT NULL,
    blockfloor integer NOT NULL,
    blockcode integer NOT NULL,
    unavailable boolean NOT NULL
);


ALTER TABLE public.room OWNER TO postgres;

--
-- Name: salesdetail; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.salesdetail AS
 SELECT salesman.salesman_id,
    salesman.city,
    salesman.name
   FROM public.salesman;


ALTER TABLE public.salesdetail OWNER TO postgres;

--
-- Name: salesman_detail; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.salesman_detail AS
 SELECT salesman.salesman_id,
    salesman.city,
    salesman.name
   FROM public.salesman;


ALTER TABLE public.salesman_detail OWNER TO postgres;

--
-- Name: salesman_do1304; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.salesman_do1304 (
    salesman_id character varying(20),
    name character varying(40),
    city character varying(30),
    commission character varying(10)
);


ALTER TABLE public.salesman_do1304 OWNER TO postgres;

--
-- Name: salesman_example; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.salesman_example AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman;


ALTER TABLE public.salesman_example OWNER TO postgres;

--
-- Name: salesman_ny; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.salesman_ny AS
 SELECT salesman.salesman_id,
    salesman.city,
    salesman.commission
   FROM public.salesman
  WHERE (((salesman.city)::text = 'New York'::text) AND (salesman.commission > 0.13));


ALTER TABLE public.salesman_ny OWNER TO postgres;

--
-- Name: salesmandetail; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.salesmandetail AS
 SELECT salesman.salesman_id,
    salesman.city,
    salesman.name
   FROM public.salesman;


ALTER TABLE public.salesmandetail OWNER TO postgres;

--
-- Name: salesown; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.salesown AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman;


ALTER TABLE public.salesown OWNER TO postgres;

--
-- Name: sample_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sample_table (
    salesman_id character(4),
    name character varying(20),
    city character varying(20),
    commission character(10)
);


ALTER TABLE public.sample_table OWNER TO postgres;

--
-- Name: scores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scores (
    id integer NOT NULL,
    score integer
);


ALTER TABLE public.scores OWNER TO postgres;

--
-- Name: soccer_city; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soccer_city (
    city_id numeric NOT NULL,
    city character varying(25) NOT NULL,
    country_id numeric NOT NULL
);


ALTER TABLE public.soccer_city OWNER TO postgres;

--
-- Name: soccer_country; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soccer_country (
    country_id numeric NOT NULL,
    country_abbr character varying(4) NOT NULL,
    country_name character varying(40) NOT NULL
);


ALTER TABLE public.soccer_country OWNER TO postgres;

--
-- Name: soccer_team; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soccer_team (
    team_id numeric NOT NULL,
    team_group character(1) NOT NULL,
    match_played numeric NOT NULL,
    won numeric NOT NULL,
    draw numeric NOT NULL,
    lost numeric NOT NULL,
    goal_for numeric NOT NULL,
    goal_agnst numeric NOT NULL,
    goal_diff numeric NOT NULL,
    points numeric NOT NULL,
    group_position numeric NOT NULL
);


ALTER TABLE public.soccer_team OWNER TO postgres;

--
-- Name: soccer_venue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soccer_venue (
    venue_id numeric NOT NULL,
    venue_name character varying(30) NOT NULL,
    city_id numeric NOT NULL,
    aud_capacity numeric NOT NULL
);


ALTER TABLE public.soccer_venue OWNER TO postgres;

--
-- Name: statements; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.statements (
    name text
);


ALTER TABLE public.statements OWNER TO postgres;

--
-- Name: stay; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stay (
    stayid integer NOT NULL,
    patient integer NOT NULL,
    room integer NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone NOT NULL
);


ALTER TABLE public.stay OWNER TO postgres;

--
-- Name: string; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.string (
    text text
);


ALTER TABLE public.string OWNER TO postgres;

--
-- Name: student; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student (
    roll integer,
    name character varying
);


ALTER TABLE public.student OWNER TO postgres;

--
-- Name: student1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student1 (
    roll integer,
    name character varying
);


ALTER TABLE public.student1 OWNER TO postgres;

--
-- Name: sybba; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sybba (
    ord_num numeric(6,0) NOT NULL,
    ord_amount numeric(12,2),
    ord_date date NOT NULL,
    cust_code character(6) NOT NULL,
    agent_code character(6) NOT NULL
);


ALTER TABLE public.sybba OWNER TO postgres;

--
-- Name: table1; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.table1 (
    "Customer Name" character varying(30),
    city character varying(15),
    "Salesman" character varying(30),
    commission numeric(5,2)
);


ALTER TABLE public.table1 OWNER TO postgres;

--
-- Name: team_coaches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.team_coaches (
    team_id numeric NOT NULL,
    coach_id numeric NOT NULL
);


ALTER TABLE public.team_coaches OWNER TO postgres;

--
-- Name: temp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.temp (
    customer_id numeric(5,0),
    cust_name character varying(30),
    city character varying(15),
    grade numeric(3,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.temp OWNER TO postgres;

--
-- Name: tempa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tempa (
    customer_id numeric(5,0),
    cust_name character varying(30),
    city character varying(15),
    grade numeric(3,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.tempa OWNER TO postgres;

--
-- Name: tempcustomer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tempcustomer (
    customer_id numeric(5,0),
    cust_name character varying(30),
    city character varying(15),
    grade numeric(3,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.tempcustomer OWNER TO postgres;

--
-- Name: temphi; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.temphi (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.temphi OWNER TO postgres;

--
-- Name: tempp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tempp (
    customer_id numeric(5,0),
    cust_name character varying(30),
    city character varying(15),
    grade numeric(3,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.tempp OWNER TO postgres;

--
-- Name: tempp11; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tempp11 (
    customer_id numeric(5,0),
    cust_name character varying(30),
    city character varying(15),
    grade numeric(3,0),
    salesman_id numeric(5,0)
);


ALTER TABLE public.tempp11 OWNER TO postgres;

--
-- Name: tempsalesman; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tempsalesman (
    salesman_id numeric(5,0),
    name character varying(30),
    city character varying(15),
    commission numeric(5,2)
);


ALTER TABLE public.tempsalesman OWNER TO postgres;

--
-- Name: test; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test (
    x integer
);


ALTER TABLE public.test OWNER TO postgres;

--
-- Name: teste; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teste (
    salesman_id numeric(5,0),
    count bigint
);


ALTER TABLE public.teste OWNER TO postgres;

--
-- Name: testtable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.testtable (
    col1 character varying(30) NOT NULL
);


ALTER TABLE public.testtable OWNER TO postgres;

--
-- Name: TABLE testtable; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.testtable IS 'a temporary table for some queries ';


--
-- Name: testtesing; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.testtesing AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman
  WHERE ((salesman.city)::text = 'New York'::text);


ALTER TABLE public.testtesing OWNER TO postgres;

--
-- Name: testtest; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.testtest AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman;


ALTER TABLE public.testtest OWNER TO postgres;

--
-- Name: trained_in; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trained_in (
    physician integer NOT NULL,
    treatment integer NOT NULL,
    certificationdate date NOT NULL,
    certificationexpires date NOT NULL
);


ALTER TABLE public.trained_in OWNER TO postgres;

--
-- Name: trenta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trenta (
    numeri integer
);


ALTER TABLE public.trenta OWNER TO postgres;

--
-- Name: tt; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tt (
    name integer
);


ALTER TABLE public.tt OWNER TO postgres;

--
-- Name: undergoes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.undergoes (
    patient integer NOT NULL,
    procedure integer NOT NULL,
    stay integer NOT NULL,
    date timestamp without time zone NOT NULL,
    physician integer NOT NULL,
    assistingnurse integer
);


ALTER TABLE public.undergoes OWNER TO postgres;

--
-- Name: v1; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v1 AS
 SELECT o.ord_no,
    c.cust_name,
    s.name
   FROM ((public.orders o
     JOIN public.customer c ON ((o.customer_id = c.customer_id)))
     JOIN public.salesman s ON ((o.salesman_id = s.salesman_id)));


ALTER TABLE public.v1 OWNER TO postgres;

--
-- Name: view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.view AS
 SELECT salesman.salesman_id,
    salesman.name,
    salesman.city
   FROM public.salesman;


ALTER TABLE public.view OWNER TO postgres;

--
-- Name: vowl; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vowl (
    cust_name character varying(30),
    "substring" text
);


ALTER TABLE public.vowl OWNER TO postgres;

--
-- Name: zebras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zebras (
    id integer NOT NULL,
    score integer,
    date date DEFAULT now()
);


ALTER TABLE public.zebras OWNER TO postgres;

--
-- Name: zz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zz (
    customer_id numeric(5,0),
    avg numeric
);


ALTER TABLE public.zz OWNER TO postgres;

--
-- Data for Name: a; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.a (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5007	Paul Adam	Rome	0.13
5003	Lauson Hen	San Jose	0.12
\.


--
-- Data for Name: abc; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.abc (emp_dept, emp_idno, rnk2) FROM stdin;
27	631548	1
27	539569	2
47	748681	1
47	659831	2
47	444527	3
57	847674	1
57	843795	2
57	839139	3
57	555935	4
57	127323	5
63	733843	1
63	526689	2
63	328717	3
\.


--
-- Data for Name: actor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor (act_id, act_fname, act_lname, act_gender) FROM stdin;
101	James               	Stewart             	M
102	Deborah             	Kerr                	F
103	Peter               	OToole              	M
104	Robert              	De Niro             	M
105	F. Murray           	Abraham             	M
106	Harrison            	Ford                	M
107	Nicole              	Kidman              	F
108	Stephen             	Baldwin             	M
109	Jack                	Nicholson           	M
110	Mark                	Wahlberg            	M
111	Woody               	Allen               	M
112	Claire              	Danes               	F
113	Tim                 	Robbins             	M
114	Kevin               	Spacey              	M
115	Kate                	Winslet             	F
116	Robin               	Williams            	M
117	Jon                 	Voight              	M
118	Ewan                	McGregor            	M
119	Christian           	Bale                	M
120	Maggie              	Gyllenhaal          	F
121	Dev                 	Patel               	M
122	Sigourney           	Weaver              	F
123	David               	Aston               	M
124	Ali                 	Astin               	F
\.


--
-- Data for Name: actorsbackup2017; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actorsbackup2017 (act_fname, act_lname) FROM stdin;
James               	Stewart             
Deborah             	Kerr                
Peter               	OToole              
Robert              	De Niro             
F. Murray           	Abraham             
Harrison            	Ford                
Nicole              	Kidman              
Stephen             	Baldwin             
Jack                	Nicholson           
Mark                	Wahlberg            
Woody               	Allen               
Claire              	Danes               
Tim                 	Robbins             
Kevin               	Spacey              
Kate                	Winslet             
Robin               	Williams            
Jon                 	Voight              
Ewan                	McGregor            
Christian           	Bale                
Maggie              	Gyllenhaal          
Dev                 	Patel               
Sigourney           	Weaver              
David               	Aston               
Ali                 	Astin               
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.address (city) FROM stdin;
New York
New York
Moncow
California
London
Paris
Berlin
London
\.


--
-- Data for Name: affiliated_with; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.affiliated_with (physician, department, primaryaffiliation) FROM stdin;
1	1	t
2	1	t
3	1	f
3	2	t
4	1	t
5	1	t
6	2	t
7	1	f
7	2	t
8	1	t
9	3	t
\.


--
-- Data for Name: ahmed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ahmed (employee_id, department_id, salary) FROM stdin;
100	90	24000.00
101	90	17000.00
102	90	17000.00
103	60	9000.00
104	60	6000.00
105	60	4800.00
106	60	4800.00
107	60	4200.00
108	100	12000.00
109	100	9000.00
110	100	8200.00
111	100	7700.00
112	100	7800.00
113	100	6900.00
114	30	11000.00
115	30	3100.00
116	30	2900.00
117	30	2800.00
118	30	2600.00
119	30	2500.00
120	50	8000.00
121	50	8200.00
122	50	7900.00
123	50	6500.00
124	50	5800.00
125	50	3200.00
126	50	2700.00
127	50	2400.00
128	50	2200.00
129	50	3300.00
130	50	2800.00
131	50	2500.00
132	50	2100.00
133	50	3300.00
134	50	2900.00
135	50	2400.00
136	50	2200.00
137	50	3600.00
138	50	3200.00
139	50	2700.00
140	50	2500.00
141	50	3500.00
142	50	3100.00
143	50	2600.00
144	50	2500.00
145	80	14000.00
146	80	13500.00
147	80	12000.00
148	80	11000.00
149	80	10500.00
150	80	10000.00
151	80	9500.00
152	80	9000.00
153	80	8000.00
154	80	7500.00
155	80	7000.00
156	80	10000.00
157	80	9500.00
158	80	9000.00
159	80	8000.00
160	80	7500.00
161	80	7000.00
162	80	10500.00
163	80	9500.00
164	80	7200.00
165	80	6800.00
166	80	6400.00
167	80	6200.00
168	80	11500.00
169	80	10000.00
170	80	9600.00
171	80	7400.00
172	80	7300.00
173	80	6100.00
174	80	11000.00
175	80	8800.00
176	80	8600.00
177	80	8400.00
178	0	7000.00
179	80	6200.00
180	50	3200.00
181	50	3100.00
182	50	2500.00
183	50	2800.00
184	50	4200.00
185	50	4100.00
186	50	3400.00
187	50	3000.00
188	50	3800.00
189	50	3600.00
190	50	2900.00
191	50	2500.00
192	50	4000.00
193	50	3900.00
194	50	3200.00
195	50	2800.00
196	50	3100.00
197	50	3000.00
198	50	2600.00
199	50	2600.00
200	10	4400.00
201	20	13000.00
202	20	6000.00
203	40	6500.00
204	70	10000.00
205	110	12000.00
206	110	8300.00
\.


--
-- Data for Name: appointment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.appointment (appointmentid, patient, prepnurse, physician, start_dt_time, end_dt_time, examinationroom) FROM stdin;
13216584	100000001	101	1	2008-04-24 10:00:00	2008-04-24 11:00:00	A
26548913	100000002	101	2	2008-04-24 10:00:00	2008-04-24 11:00:00	B
36549879	100000001	102	1	2008-04-25 10:00:00	2008-04-25 11:00:00	A
46846589	100000004	103	4	2008-04-25 10:00:00	2008-04-25 11:00:00	B
59871321	100000004	\N	4	2008-04-26 10:00:00	2008-04-26 11:00:00	C
69879231	100000003	103	2	2008-04-26 11:00:00	2008-04-26 12:00:00	C
76983231	100000001	\N	3	2008-04-26 12:00:00	2008-04-26 13:00:00	C
86213939	100000004	102	9	2008-04-27 10:00:00	2008-04-21 11:00:00	A
93216548	100000002	101	2	2008-04-27 10:00:00	2008-04-27 11:00:00	B
\.


--
-- Data for Name: asst_referee_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.asst_referee_mast (ass_ref_id, ass_ref_name, country_id) FROM stdin;
80034	Tomas Mokrusch	1205
80038	Martin Wilczek	1205
80004	Simon Beck	1206
80006	Stephen Child	1206
80007	Jake Collin	1206
80014	Mike Mullarkey	1206
80026	Frederic Cano	1207
80028	Nicolas Danos	1207
80005	Mark Borsch	1208
80013	Stefan Lupp	1208
80016	Gyorgy Ring	1209
80020	Vencel Toth	1209
80033	Damien McGraith	1215
80008	Elenito Di Liberatore	1211
80019	Mauro Tonolini	1211
80021	Sander van Roekel	1226
80024	Erwin Zeinstra	1226
80025	Frank Andas	1229
80031	Kim Haglund	1229
80012	Tomasz Listkiewicz	1213
80018	Pawel Sokolnicki	1213
80029	Sebastian Gheorghe	1216
80036	Octavian Sovre	1216
80030	Nikolay Golubev	1217
80032	Tikhon Kalugin	1217
80037	Anton Averyanov	1217
80027	Frank Connor	1228
80010	Dalibor Durdevic	1227
80017	Milovan Ristic	1227
80035	Roman Slysko	1218
80001	Jure Praprotnik	1225
80002	Robert Vukan	1225
80003	Roberto Alonso Fernandez	1219
80023	Juan Yuste Jimenez	1219
80011	Mathias Klasenius	1220
80022	Daniel Warnmark	1220
80009	Bahattin Duran	1222
80015	Tarik Ongun	1222
\.


--
-- Data for Name: bh; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bh (name, emp_id, process) FROM stdin;
Pandey	333445	Mobile
Bhupinder	301144	Mobile
Kapil	301146	Mobile
Sanjay	301147	Mobile
Manjeet	301145	Mobile
\.


--
-- Data for Name: bitch; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bitch (sum) FROM stdin;
25
\.


--
-- Data for Name: blah; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blah (ord_no, purch_amt, ord_date, customer_id, salesman_id) FROM stdin;
70009	270.65	2012-09-10	3001	5005
70002	65.26	2012-10-05	3002	5001
70004	110.50	2012-08-17	3009	5003
70005	2400.60	2012-07-27	3007	5001
70008	5760.00	2012-09-10	3002	5001
70010	1983.43	2012-10-10	3004	5006
70003	2480.40	2012-10-10	3009	5003
70011	75.29	2012-08-17	3003	5007
70013	3045.60	2012-04-25	3002	5001
70001	150.50	2012-10-05	3005	5002
70007	948.50	2012-09-10	3005	5002
70012	250.45	2012-06-27	3008	5002
\.


--
-- Data for Name: block; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.block (blockfloor, blockcode) FROM stdin;
1	1
1	2
1	3
2	1
2	2
2	3
3	1
3	2
3	3
4	1
4	2
4	3
\.


--
-- Data for Name: casino; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.casino (pricerange, events, location, casino) FROM stdin;
\.


--
-- Data for Name: coach_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coach_mast (coach_id, coach_name) FROM stdin;
5550	Gianni De Biasi
5551	Marcel Koller
5552	Marc Wilmots
5553	Ante Cacic
5554	Pavel Vrba
5555	Roy Hodgson
5556	Didier Deschamps
5557	Joachim Low
5558	Bernd Storck
5559	Lars Lagerback
5560	Heimir Hallgrímsson
5561	Antonio Conte
5562	Michael ONeill
5563	Adam Nawalka
5564	Fernando Santos
5565	Martin ONeill
5566	Anghel Iordanescu
5567	Leonid Slutski
5568	Jan Kozak
5569	Vicente del Bosque
5570	Erik Hamren
5571	Vladimir Petkovic
5572	Fatih Terim
5573	Mykhailo Fomenko
5574	Chris Coleman
\.


--
-- Data for Name: col1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.col1 ("?column?") FROM stdin;
1
\.


--
-- Data for Name: company_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.company_mast (com_id, com_name) FROM stdin;
11	Samsung
12	iBall
13	Epsion
14	Zebronics
15	Asus
16	Frontech
\.


--
-- Data for Name: countries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.countries (country_id, country_name, region_id) FROM stdin;
AR	Argentina	2
AU	Australia	3
BE	Belgium	1
BR	Brazil	2
CA	Canada	2
CH	Switzerland	1
CN	China	3
DE	Germany	1
DK	Denmark	1
EG	Egypt	4
FR	France	1
HK	HongKong	3
IL	Israel	4
IN	India	3
IT	Italy	1
JP	Japan	3
KW	Kuwait	4
MX	Mexico	2
NG	Nigeria	4
NL	Netherlands	1
SG	Singapore	3
UK	United Kingdom	1
US	United States of America	2
ZM	Zambia	4
ZW	Zimbabwe	4
\.


--
-- Data for Name: customer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customer (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3007	Brad Davis	New York	200	5001
3005	Graham Zusi	California	200	5002
3008	Julian Green	London	300	5002
3004	Fabian Johnson	Paris	300	5006
3009	Geoff Cameron	Berlin	100	5003
3003	Jozy Altidor	Moscow	200	5007
3001	Brad Guzan	London	\N	5005
\.


--
-- Data for Name: customer_backup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customer_backup (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3007	Brad Davis	New York	200	5001
3003	Jozy Altidor	Moncow	200	5007
3005	Graham Zusi	California	200	5002
3008	Julian Green	London	300	5002
3004	Fabian Johnson	Paris	300	5006
3009	Geoff Cameron	Berlin	100	5003
3001	Brad Guzan	London	\N	5005
\.


--
-- Data for Name: customer_id; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customer_id (ord_no, purch_amt, ord_date, customer_id, salesman_id) FROM stdin;
70002	65.26	2012-10-05	3002	5001
70008	5760.00	2012-09-10	3002	5001
70013	3045.60	2012-04-25	3002	5001
\.


--
-- Data for Name: customer_id_123; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customer_id_123 (ord_no, purch_amt, ord_date, customer_id, salesman_id) FROM stdin;
70002	65.26	2012-10-05	3002	5001
70008	5760.00	2012-09-10	3002	5001
70013	3045.60	2012-04-25	3002	5001
\.


--
-- Data for Name: department; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.department (departmentid, name, head) FROM stdin;
1	General Medicine	4
2	Surgery	7
3	Psychiatry	9
\.


--
-- Data for Name: department_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.department_detail (first_name, last_name, department_id, department_name) FROM stdin;
Steven	King	90	Executive
Neena	Kochhar	90	Executive
Lex	De Haan	90	Executive
Alexander	Hunold	60	IT
Bruce	Ernst	60	IT
David	Austin	60	IT
Valli	Pataballa	60	IT
Diana	Lorentz	60	IT
Nancy	Greenberg	100	Finance
Daniel	Faviet	100	Finance
John	Chen	100	Finance
Ismael	Sciarra	100	Finance
Jose Manuel	Urman	100	Finance
Luis	Popp	100	Finance
Den	Raphaely	30	Purchasing
Alexander	Khoo	30	Purchasing
Shelli	Baida	30	Purchasing
Sigal	Tobias	30	Purchasing
Guy	Himuro	30	Purchasing
Karen	Colmenares	30	Purchasing
Matthew	Weiss	50	Shipping
Adam	Fripp	50	Shipping
Payam	Kaufling	50	Shipping
Shanta	Vollman	50	Shipping
Kevin	Mourgos	50	Shipping
Julia	Nayer	50	Shipping
Irene	Mikkilineni	50	Shipping
James	Landry	50	Shipping
Steven	Markle	50	Shipping
Laura	Bissot	50	Shipping
Mozhe	Atkinson	50	Shipping
James	Marlow	50	Shipping
TJ	Olson	50	Shipping
Jason	Mallin	50	Shipping
Michael	Rogers	50	Shipping
Ki	Gee	50	Shipping
Hazel	Philtanker	50	Shipping
Renske	Ladwig	50	Shipping
Stephen	Stiles	50	Shipping
John	Seo	50	Shipping
Joshua	Patel	50	Shipping
Trenna	Rajs	50	Shipping
Curtis	Davies	50	Shipping
Randall	Matos	50	Shipping
Peter	Vargas	50	Shipping
John	Russell	80	Sales
Karen	Partners	80	Sales
Alberto	Errazuriz	80	Sales
Gerald	Cambrault	80	Sales
Eleni	Zlotkey	80	Sales
Peter	Tucker	80	Sales
David	Bernstein	80	Sales
Peter	Hall	80	Sales
Christopher	Olsen	80	Sales
Nanette	Cambrault	80	Sales
Oliver	Tuvault	80	Sales
Janette	King	80	Sales
Patrick	Sully	80	Sales
Allan	McEwen	80	Sales
Lindsey	Smith	80	Sales
Louise	Doran	80	Sales
Sarath	Sewall	80	Sales
Clara	Vishney	80	Sales
Danielle	Greene	80	Sales
Mattea	Marvins	80	Sales
David	Lee	80	Sales
Sundar	Ande	80	Sales
Amit	Banda	80	Sales
Lisa	Ozer	80	Sales
Harrison	Bloom	80	Sales
Tayler	Fox	80	Sales
William	Smith	80	Sales
Elizabeth	Bates	80	Sales
Sundita	Kumar	80	Sales
Ellen	Abel	80	Sales
Alyssa	Hutton	80	Sales
Jonathon	Taylor	80	Sales
Jack	Livingston	80	Sales
Charles	Johnson	80	Sales
Winston	Taylor	50	Shipping
Jean	Fleaur	50	Shipping
Martha	Sullivan	50	Shipping
Girard	Geoni	50	Shipping
Nandita	Sarchand	50	Shipping
Alexis	Bull	50	Shipping
Julia	Dellinger	50	Shipping
Anthony	Cabrio	50	Shipping
Kelly	Chung	50	Shipping
Jennifer	Dilly	50	Shipping
Timothy	Gates	50	Shipping
Randall	Perkins	50	Shipping
Sarah	Bell	50	Shipping
Britney	Everett	50	Shipping
Samuel	McCain	50	Shipping
Vance	Jones	50	Shipping
Alana	Walsh	50	Shipping
Kevin	Feeney	50	Shipping
Donald	OConnell	50	Shipping
Douglas	Grant	50	Shipping
Jennifer	Whalen	10	Administration
Michael	Hartstein	20	Marketing
Pat	Fay	20	Marketing
Susan	Mavris	40	Human Resources
Hermann	Baer	70	Public Relations
Shelley	Higgins	110	Accounting
William	Gietz	110	Accounting
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.departments (department_id, department_name, manager_id, location_id) FROM stdin;
10	Administration	200	1700
20	Marketing	201	1800
30	Purchasing	114	1700
40	Human Resources	203	2400
50	Shipping	121	1500
60	IT	103	1400
70	Public Relations	204	2700
80	Sales	145	2500
90	Executive	100	1700
100	Finance	108	1700
110	Accounting	205	1700
120	Treasury	0	1700
130	Corporate Tax	0	1700
140	Control And Credit	0	1700
150	Shareholder Services	0	1700
160	Benefits	0	1700
170	Manufacturing	0	1700
180	Construction	0	1700
190	Contracting	0	1700
200	Operations	0	1700
210	IT Support	0	1700
220	NOC	0	1700
230	IT Helpdesk	0	1700
240	Government Sales	0	1700
250	Retail Sales	0	1700
260	Recruiting	0	1700
270	Payroll	0	1700
\.


--
-- Data for Name: director; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.director (dir_id, dir_fname, dir_lname) FROM stdin;
201	Alfred              	Hitchcock           
202	Jack                	Clayton             
203	David               	Lean                
204	Michael             	Cimino              
205	Milos               	Forman              
206	Ridley              	Scott               
207	Stanley             	Kubrick             
208	Bryan               	Singer              
209	Roman               	Polanski            
210	Paul                	Thomas Anderson     
211	Woody               	Allen               
212	Hayao               	Miyazaki            
213	Frank               	Darabont            
214	Sam                 	Mendes              
215	James               	Cameron             
216	Gus                 	Van Sant            
217	John                	Boorman             
218	Danny               	Boyle               
219	Christopher         	Nolan               
220	Richard             	Kelly               
221	Kevin               	Spacey              
222	Andrei              	Tarkovsky           
223	Peter               	Jackson             
\.


--
-- Data for Name: duplicate; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.duplicate (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5007	Paul Adam	Rome	0.13
5003	Lauson Hen	San Jose	0.12
\.


--
-- Data for Name: elephants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.elephants (id, name, date) FROM stdin;
1	\N	2015-12-15
2	\N	2015-12-15
\.


--
-- Data for Name: emp; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emp (ename, salary, eid) FROM stdin;
\.


--
-- Data for Name: emp_department; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emp_department (dpt_code, dpt_name, dpt_allotment) FROM stdin;
57	IT             	65000
63	Finance        	15000
47	HR             	240000
27	RD             	55000
89	QC             	75000
\.


--
-- Data for Name: emp_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emp_details (emp_idno, emp_fname, emp_lname, emp_dept) FROM stdin;
631548	Alan           	Snappy         	27
839139	Maria          	Foster         	57
127323	Michale        	Robbin         	57
526689	Carlos         	Snares         	63
843795	Enric          	Dosio          	57
328717	Jhon           	Snares         	63
444527	Joseph         	Dosni          	47
659831	Zanifer        	Emily          	47
847674	Kuleswar       	Sitaraman      	57
748681	Henrey         	Gabriel        	47
555935	Alex           	Manuel         	57
539569	George         	Mardy          	27
733843	Mario          	Saule          	63
\.


--
-- Data for Name: employee; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employee (empno, ename) FROM stdin;
\.


--
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employees (employee_id, first_name, last_name, email, phone_number, hire_date, job_id, salary, commission_pct, manager_id, department_id) FROM stdin;
100	Steven	King	SKING	515.123.4567	2003-06-17	AD_PRES	24000.00	0.00	0	90
101	Neena	Kochhar	NKOCHHAR	515.123.4568	2005-09-21	AD_VP	17000.00	0.00	100	90
102	Lex	De Haan	LDEHAAN	515.123.4569	2001-01-13	AD_VP	17000.00	0.00	100	90
103	Alexander	Hunold	AHUNOLD	590.423.4567	2006-01-03	IT_PROG	9000.00	0.00	102	60
104	Bruce	Ernst	BERNST	590.423.4568	2007-05-21	IT_PROG	6000.00	0.00	103	60
105	David	Austin	DAUSTIN	590.423.4569	2005-06-25	IT_PROG	4800.00	0.00	103	60
106	Valli	Pataballa	VPATABAL	590.423.4560	2006-02-05	IT_PROG	4800.00	0.00	103	60
107	Diana	Lorentz	DLORENTZ	590.423.5567	2007-02-07	IT_PROG	4200.00	0.00	103	60
108	Nancy	Greenberg	NGREENBE	515.124.4569	2002-08-17	FI_MGR	12000.00	0.00	101	100
109	Daniel	Faviet	DFAVIET	515.124.4169	2002-08-16	FI_ACCOUNT	9000.00	0.00	108	100
110	John	Chen	JCHEN	515.124.4269	2005-09-28	FI_ACCOUNT	8200.00	0.00	108	100
111	Ismael	Sciarra	ISCIARRA	515.124.4369	2005-09-30	FI_ACCOUNT	7700.00	0.00	108	100
112	Jose Manuel	Urman	JMURMAN	515.124.4469	2006-03-07	FI_ACCOUNT	7800.00	0.00	108	100
113	Luis	Popp	LPOPP	515.124.4567	2007-12-07	FI_ACCOUNT	6900.00	0.00	108	100
114	Den	Raphaely	DRAPHEAL	515.127.4561	2002-12-07	PU_MAN	11000.00	0.00	100	30
115	Alexander	Khoo	AKHOO	515.127.4562	2003-05-18	PU_CLERK	3100.00	0.00	114	30
116	Shelli	Baida	SBAIDA	515.127.4563	2005-12-24	PU_CLERK	2900.00	0.00	114	30
117	Sigal	Tobias	STOBIAS	515.127.4564	2005-07-24	PU_CLERK	2800.00	0.00	114	30
118	Guy	Himuro	GHIMURO	515.127.4565	2006-11-15	PU_CLERK	2600.00	0.00	114	30
119	Karen	Colmenares	KCOLMENA	515.127.4566	2007-08-10	PU_CLERK	2500.00	0.00	114	30
120	Matthew	Weiss	MWEISS	650.123.1234	2004-07-18	ST_MAN	8000.00	0.00	100	50
121	Adam	Fripp	AFRIPP	650.123.2234	2005-04-10	ST_MAN	8200.00	0.00	100	50
122	Payam	Kaufling	PKAUFLIN	650.123.3234	2003-05-01	ST_MAN	7900.00	0.00	100	50
123	Shanta	Vollman	SVOLLMAN	650.123.4234	2005-10-10	ST_MAN	6500.00	0.00	100	50
124	Kevin	Mourgos	KMOURGOS	650.123.5234	2007-11-16	ST_MAN	5800.00	0.00	100	50
125	Julia	Nayer	JNAYER	650.124.1214	2005-07-16	ST_CLERK	3200.00	0.00	120	50
126	Irene	Mikkilineni	IMIKKILI	650.124.1224	2006-09-28	ST_CLERK	2700.00	0.00	120	50
127	James	Landry	JLANDRY	650.124.1334	2007-01-14	ST_CLERK	2400.00	0.00	120	50
128	Steven	Markle	SMARKLE	650.124.1434	2008-03-08	ST_CLERK	2200.00	0.00	120	50
129	Laura	Bissot	LBISSOT	650.124.5234	2005-08-20	ST_CLERK	3300.00	0.00	121	50
130	Mozhe	Atkinson	MATKINSO	650.124.6234	2005-10-30	ST_CLERK	2800.00	0.00	121	50
131	James	Marlow	JAMRLOW	650.124.7234	2005-02-16	ST_CLERK	2500.00	0.00	121	50
132	TJ	Olson	TJOLSON	650.124.8234	2007-04-10	ST_CLERK	2100.00	0.00	121	50
133	Jason	Mallin	JMALLIN	650.127.1934	2004-06-14	ST_CLERK	3300.00	0.00	122	50
134	Michael	Rogers	MROGERS	650.127.1834	2006-08-26	ST_CLERK	2900.00	0.00	122	50
135	Ki	Gee	KGEE	650.127.1734	2007-12-12	ST_CLERK	2400.00	0.00	122	50
136	Hazel	Philtanker	HPHILTAN	650.127.1634	2008-02-06	ST_CLERK	2200.00	0.00	122	50
137	Renske	Ladwig	RLADWIG	650.121.1234	2003-07-14	ST_CLERK	3600.00	0.00	123	50
138	Stephen	Stiles	SSTILES	650.121.2034	2005-10-26	ST_CLERK	3200.00	0.00	123	50
139	John	Seo	JSEO	650.121.2019	2006-02-12	ST_CLERK	2700.00	0.00	123	50
140	Joshua	Patel	JPATEL	650.121.1834	2006-04-06	ST_CLERK	2500.00	0.00	123	50
141	Trenna	Rajs	TRAJS	650.121.8009	2003-10-17	ST_CLERK	3500.00	0.00	124	50
142	Curtis	Davies	CDAVIES	650.121.2994	2005-01-29	ST_CLERK	3100.00	0.00	124	50
143	Randall	Matos	RMATOS	650.121.2874	2006-03-15	ST_CLERK	2600.00	0.00	124	50
144	Peter	Vargas	PVARGAS	650.121.2004	2006-07-09	ST_CLERK	2500.00	0.00	124	50
145	John	Russell	JRUSSEL	011.44.1344.429268	2004-10-01	SA_MAN	14000.00	0.40	100	80
146	Karen	Partners	KPARTNER	011.44.1344.467268	2005-01-05	SA_MAN	13500.00	0.30	100	80
147	Alberto	Errazuriz	AERRAZUR	011.44.1344.429278	2005-03-10	SA_MAN	12000.00	0.30	100	80
148	Gerald	Cambrault	GCAMBRAU	011.44.1344.619268	2007-10-15	SA_MAN	11000.00	0.30	100	80
149	Eleni	Zlotkey	EZLOTKEY	011.44.1344.429018	2008-01-29	SA_MAN	10500.00	0.20	100	80
150	Peter	Tucker	PTUCKER	011.44.1344.129268	2005-01-30	SA_REP	10000.00	0.30	145	80
151	David	Bernstein	DBERNSTE	011.44.1344.345268	2005-03-24	SA_REP	9500.00	0.25	145	80
152	Peter	Hall	PHALL	011.44.1344.478968	2005-08-20	SA_REP	9000.00	0.25	145	80
153	Christopher	Olsen	COLSEN	011.44.1344.498718	2006-03-30	SA_REP	8000.00	0.20	145	80
154	Nanette	Cambrault	NCAMBRAU	011.44.1344.987668	2006-12-09	SA_REP	7500.00	0.20	145	80
155	Oliver	Tuvault	OTUVAULT	011.44.1344.486508	2007-11-23	SA_REP	7000.00	0.15	145	80
156	Janette	King	JKING	011.44.1345.429268	2004-01-30	SA_REP	10000.00	0.35	146	80
157	Patrick	Sully	PSULLY	011.44.1345.929268	2004-03-04	SA_REP	9500.00	0.35	146	80
158	Allan	McEwen	AMCEWEN	011.44.1345.829268	2004-08-01	SA_REP	9000.00	0.35	146	80
159	Lindsey	Smith	LSMITH	011.44.1345.729268	2005-03-10	SA_REP	8000.00	0.30	146	80
160	Louise	Doran	LDORAN	011.44.1345.629268	2005-12-15	SA_REP	7500.00	0.30	146	80
161	Sarath	Sewall	SSEWALL	011.44.1345.529268	2006-11-03	SA_REP	7000.00	0.25	146	80
162	Clara	Vishney	CVISHNEY	011.44.1346.129268	2005-11-11	SA_REP	10500.00	0.25	147	80
163	Danielle	Greene	DGREENE	011.44.1346.229268	2007-03-19	SA_REP	9500.00	0.15	147	80
164	Mattea	Marvins	MMARVINS	011.44.1346.329268	2008-01-24	SA_REP	7200.00	0.10	147	80
165	David	Lee	DLEE	011.44.1346.529268	2008-02-23	SA_REP	6800.00	0.10	147	80
166	Sundar	Ande	SANDE	011.44.1346.629268	2008-03-24	SA_REP	6400.00	0.10	147	80
167	Amit	Banda	ABANDA	011.44.1346.729268	2008-04-21	SA_REP	6200.00	0.10	147	80
168	Lisa	Ozer	LOZER	011.44.1343.929268	2005-03-11	SA_REP	11500.00	0.25	148	80
169	Harrison	Bloom	HBLOOM	011.44.1343.829268	2006-03-23	SA_REP	10000.00	0.20	148	80
170	Tayler	Fox	TFOX	011.44.1343.729268	2006-01-24	SA_REP	9600.00	0.20	148	80
171	William	Smith	WSMITH	011.44.1343.629268	2007-02-23	SA_REP	7400.00	0.15	148	80
172	Elizabeth	Bates	EBATES	011.44.1343.529268	2007-03-24	SA_REP	7300.00	0.15	148	80
173	Sundita	Kumar	SKUMAR	011.44.1343.329268	2008-04-21	SA_REP	6100.00	0.10	148	80
174	Ellen	Abel	EABEL	011.44.1644.429267	2004-05-11	SA_REP	11000.00	0.30	149	80
175	Alyssa	Hutton	AHUTTON	011.44.1644.429266	2005-03-19	SA_REP	8800.00	0.25	149	80
176	Jonathon	Taylor	JTAYLOR	011.44.1644.429265	2006-03-24	SA_REP	8600.00	0.20	149	80
177	Jack	Livingston	JLIVINGS	011.44.1644.429264	2006-04-23	SA_REP	8400.00	0.20	149	80
178	Kimberely	Grant	KGRANT	011.44.1644.429263	2007-05-24	SA_REP	7000.00	0.15	149	0
179	Charles	Johnson	CJOHNSON	011.44.1644.429262	2008-01-04	SA_REP	6200.00	0.10	149	80
180	Winston	Taylor	WTAYLOR	650.507.9876	2006-01-24	SH_CLERK	3200.00	0.00	120	50
181	Jean	Fleaur	JFLEAUR	650.507.9877	2006-02-23	SH_CLERK	3100.00	0.00	120	50
182	Martha	Sullivan	MSULLIVA	650.507.9878	2007-06-21	SH_CLERK	2500.00	0.00	120	50
183	Girard	Geoni	GGEONI	650.507.9879	2008-02-03	SH_CLERK	2800.00	0.00	120	50
184	Nandita	Sarchand	NSARCHAN	650.509.1876	2004-01-27	SH_CLERK	4200.00	0.00	121	50
185	Alexis	Bull	ABULL	650.509.2876	2005-02-20	SH_CLERK	4100.00	0.00	121	50
186	Julia	Dellinger	JDELLING	650.509.3876	2006-06-24	SH_CLERK	3400.00	0.00	121	50
187	Anthony	Cabrio	ACABRIO	650.509.4876	2007-02-07	SH_CLERK	3000.00	0.00	121	50
188	Kelly	Chung	KCHUNG	650.505.1876	2005-06-14	SH_CLERK	3800.00	0.00	122	50
189	Jennifer	Dilly	JDILLY	650.505.2876	2005-08-13	SH_CLERK	3600.00	0.00	122	50
190	Timothy	Gates	TGATES	650.505.3876	2006-07-11	SH_CLERK	2900.00	0.00	122	50
191	Randall	Perkins	RPERKINS	650.505.4876	2007-12-19	SH_CLERK	2500.00	0.00	122	50
192	Sarah	Bell	SBELL	650.501.1876	2004-02-04	SH_CLERK	4000.00	0.00	123	50
193	Britney	Everett	BEVERETT	650.501.2876	2005-03-03	SH_CLERK	3900.00	0.00	123	50
194	Samuel	McCain	SMCCAIN	650.501.3876	2006-07-01	SH_CLERK	3200.00	0.00	123	50
195	Vance	Jones	VJONES	650.501.4876	2007-03-17	SH_CLERK	2800.00	0.00	123	50
196	Alana	Walsh	AWALSH	650.507.9811	2006-04-24	SH_CLERK	3100.00	0.00	124	50
197	Kevin	Feeney	KFEENEY	650.507.9822	2006-05-23	SH_CLERK	3000.00	0.00	124	50
198	Donald	OConnell	DOCONNEL	650.507.9833	2007-06-21	SH_CLERK	2600.00	0.00	124	50
199	Douglas	Grant	DGRANT	650.507.9844	2008-01-13	SH_CLERK	2600.00	0.00	124	50
200	Jennifer	Whalen	JWHALEN	515.123.4444	2003-09-17	AD_ASST	4400.00	0.00	101	10
201	Michael	Hartstein	MHARTSTE	515.123.5555	2004-02-17	MK_MAN	13000.00	0.00	100	20
202	Pat	Fay	PFAY	603.123.6666	2005-08-17	MK_REP	6000.00	0.00	201	20
203	Susan	Mavris	SMAVRIS	515.123.7777	2002-06-07	HR_REP	6500.00	0.00	101	40
204	Hermann	Baer	HBAER	515.123.8888	2002-06-07	PR_REP	10000.00	0.00	101	70
205	Shelley	Higgins	SHIGGINS	515.123.8080	2002-06-07	AC_MGR	12000.00	0.00	101	110
206	William	Gietz	WGIETZ	515.123.8181	2002-06-07	AC_ACCOUNT	8300.00	0.00	205	110
\.


--
-- Data for Name: ff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ff (salesman_id, name, city, commission, year, subject, winner, country, category) FROM stdin;
5001	James Hoog	New York	0.15	1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
5002	Nail Knite	Paris	0.13	1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
5005	Pit Alex	London	0.11	1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
5006	Mc Lyon	Paris	0.14	1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
5007	Paul Adam	Rome	0.13	1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
5003	Lauson Hen	San Jose	0.12	1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
5001	James Hoog	New York	0.15	1970	Physics                  	Louis Neel                                   	France                   	Scientist                
5002	Nail Knite	Paris	0.13	1970	Physics                  	Louis Neel                                   	France                   	Scientist                
5005	Pit Alex	London	0.11	1970	Physics                  	Louis Neel                                   	France                   	Scientist                
5006	Mc Lyon	Paris	0.14	1970	Physics                  	Louis Neel                                   	France                   	Scientist                
5007	Paul Adam	Rome	0.13	1970	Physics                  	Louis Neel                                   	France                   	Scientist                
5003	Lauson Hen	San Jose	0.12	1970	Physics                  	Louis Neel                                   	France                   	Scientist                
5001	James Hoog	New York	0.15	1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
5002	Nail Knite	Paris	0.13	1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
5005	Pit Alex	London	0.11	1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
5006	Mc Lyon	Paris	0.14	1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
5007	Paul Adam	Rome	0.13	1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
5003	Lauson Hen	San Jose	0.12	1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
5001	James Hoog	New York	0.15	1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
5002	Nail Knite	Paris	0.13	1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
5005	Pit Alex	London	0.11	1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
5006	Mc Lyon	Paris	0.14	1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
5007	Paul Adam	Rome	0.13	1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
5003	Lauson Hen	San Jose	0.12	1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
5001	James Hoog	New York	0.15	1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
5002	Nail Knite	Paris	0.13	1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
5005	Pit Alex	London	0.11	1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
5006	Mc Lyon	Paris	0.14	1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
5007	Paul Adam	Rome	0.13	1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
5003	Lauson Hen	San Jose	0.12	1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
5001	James Hoog	New York	0.15	1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
5002	Nail Knite	Paris	0.13	1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
5005	Pit Alex	London	0.11	1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
5006	Mc Lyon	Paris	0.14	1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
5007	Paul Adam	Rome	0.13	1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
5003	Lauson Hen	San Jose	0.12	1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
5001	James Hoog	New York	0.15	1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
5002	Nail Knite	Paris	0.13	1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
5005	Pit Alex	London	0.11	1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
5006	Mc Lyon	Paris	0.14	1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
5007	Paul Adam	Rome	0.13	1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
5003	Lauson Hen	San Jose	0.12	1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
5001	James Hoog	New York	0.15	1970	Economics                	Paul Samuelson                               	USA                      	Economist                
5002	Nail Knite	Paris	0.13	1970	Economics                	Paul Samuelson                               	USA                      	Economist                
5005	Pit Alex	London	0.11	1970	Economics                	Paul Samuelson                               	USA                      	Economist                
5006	Mc Lyon	Paris	0.14	1970	Economics                	Paul Samuelson                               	USA                      	Economist                
5007	Paul Adam	Rome	0.13	1970	Economics                	Paul Samuelson                               	USA                      	Economist                
5003	Lauson Hen	San Jose	0.12	1970	Economics                	Paul Samuelson                               	USA                      	Economist                
5001	James Hoog	New York	0.15	1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
5002	Nail Knite	Paris	0.13	1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
5005	Pit Alex	London	0.11	1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
5006	Mc Lyon	Paris	0.14	1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
5007	Paul Adam	Rome	0.13	1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
5003	Lauson Hen	San Jose	0.12	1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
5001	James Hoog	New York	0.15	1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
5002	Nail Knite	Paris	0.13	1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
5005	Pit Alex	London	0.11	1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
5006	Mc Lyon	Paris	0.14	1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
5007	Paul Adam	Rome	0.13	1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
5003	Lauson Hen	San Jose	0.12	1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
5001	James Hoog	New York	0.15	1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
5002	Nail Knite	Paris	0.13	1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
5005	Pit Alex	London	0.11	1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
5006	Mc Lyon	Paris	0.14	1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
5007	Paul Adam	Rome	0.13	1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
5003	Lauson Hen	San Jose	0.12	1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
5001	James Hoog	New York	0.15	1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
5002	Nail Knite	Paris	0.13	1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
5005	Pit Alex	London	0.11	1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
5006	Mc Lyon	Paris	0.14	1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
5007	Paul Adam	Rome	0.13	1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
5003	Lauson Hen	San Jose	0.12	1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
5001	James Hoog	New York	0.15	1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
5002	Nail Knite	Paris	0.13	1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
5005	Pit Alex	London	0.11	1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
5006	Mc Lyon	Paris	0.14	1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
5007	Paul Adam	Rome	0.13	1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
5003	Lauson Hen	San Jose	0.12	1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
5001	James Hoog	New York	0.15	1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
5002	Nail Knite	Paris	0.13	1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
5005	Pit Alex	London	0.11	1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
5006	Mc Lyon	Paris	0.14	1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
5007	Paul Adam	Rome	0.13	1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
5003	Lauson Hen	San Jose	0.12	1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
5001	James Hoog	New York	0.15	1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
5002	Nail Knite	Paris	0.13	1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
5005	Pit Alex	London	0.11	1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
5006	Mc Lyon	Paris	0.14	1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
5007	Paul Adam	Rome	0.13	1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
5003	Lauson Hen	San Jose	0.12	1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
5001	James Hoog	New York	0.15	1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
5002	Nail Knite	Paris	0.13	1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
5005	Pit Alex	London	0.11	1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
5006	Mc Lyon	Paris	0.14	1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
5007	Paul Adam	Rome	0.13	1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
5003	Lauson Hen	San Jose	0.12	1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
5001	James Hoog	New York	0.15	1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
5002	Nail Knite	Paris	0.13	1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
5005	Pit Alex	London	0.11	1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
5006	Mc Lyon	Paris	0.14	1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
5007	Paul Adam	Rome	0.13	1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
5003	Lauson Hen	San Jose	0.12	1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
5001	James Hoog	New York	0.15	1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
5002	Nail Knite	Paris	0.13	1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
5005	Pit Alex	London	0.11	1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
5006	Mc Lyon	Paris	0.14	1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
5007	Paul Adam	Rome	0.13	1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
5003	Lauson Hen	San Jose	0.12	1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
5001	James Hoog	New York	0.15	1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
5002	Nail Knite	Paris	0.13	1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
5005	Pit Alex	London	0.11	1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
5006	Mc Lyon	Paris	0.14	1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
5007	Paul Adam	Rome	0.13	1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
5003	Lauson Hen	San Jose	0.12	1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
5001	James Hoog	New York	0.15	1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
5002	Nail Knite	Paris	0.13	1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
5005	Pit Alex	London	0.11	1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
5006	Mc Lyon	Paris	0.14	1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
5007	Paul Adam	Rome	0.13	1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
5003	Lauson Hen	San Jose	0.12	1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
5001	James Hoog	New York	0.15	1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
5002	Nail Knite	Paris	0.13	1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
5005	Pit Alex	London	0.11	1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
5006	Mc Lyon	Paris	0.14	1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
5007	Paul Adam	Rome	0.13	1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
5003	Lauson Hen	San Jose	0.12	1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
5001	James Hoog	New York	0.15	1987	Economics                	Robert Solow                                 	USA                      	Economist                
5002	Nail Knite	Paris	0.13	1987	Economics                	Robert Solow                                 	USA                      	Economist                
5005	Pit Alex	London	0.11	1987	Economics                	Robert Solow                                 	USA                      	Economist                
5006	Mc Lyon	Paris	0.14	1987	Economics                	Robert Solow                                 	USA                      	Economist                
5007	Paul Adam	Rome	0.13	1987	Economics                	Robert Solow                                 	USA                      	Economist                
5003	Lauson Hen	San Jose	0.12	1987	Economics                	Robert Solow                                 	USA                      	Economist                
5001	James Hoog	New York	0.15	1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
5002	Nail Knite	Paris	0.13	1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
5005	Pit Alex	London	0.11	1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
5006	Mc Lyon	Paris	0.14	1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
5007	Paul Adam	Rome	0.13	1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
5003	Lauson Hen	San Jose	0.12	1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
5001	James Hoog	New York	0.15	1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
5002	Nail Knite	Paris	0.13	1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
5005	Pit Alex	London	0.11	1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
5006	Mc Lyon	Paris	0.14	1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
5007	Paul Adam	Rome	0.13	1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
5003	Lauson Hen	San Jose	0.12	1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
\.


--
-- Data for Name: fg; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fg (customer_id, avg) FROM stdin;
3007	2400.6000000000000000
3008	250.4500000000000000
3002	2956.9533333333333333
3001	270.6500000000000000
3009	1295.4500000000000000
3004	1983.4300000000000000
3003	75.2900000000000000
3005	549.5000000000000000
\.


--
-- Data for Name: game_scores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.game_scores (id, name, score) FROM stdin;
1	James	90
2	James	55
3	James	150
4	James	50
5	Mary	110
6	Mary	160
7	Ron	120
8	Ron	90
9	Ron	200
\.


--
-- Data for Name: genres; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.genres (gen_id, gen_title) FROM stdin;
1001	Action              
1002	Adventure           
1003	Animation           
1004	Biography           
1005	Comedy              
1006	Crime               
1007	Drama               
1008	Horror              
1009	Music               
1010	Mystery             
1011	Romance             
1012	Thriller            
1013	War                 
\.


--
-- Data for Name: goal_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.goal_details (goal_id, match_no, player_id, team_id, goal_time, goal_type, play_stage, goal_schedule, goal_half) FROM stdin;
1	1	160159	1207	57	N	G	NT	2
2	1	160368	1216	65	P	G	NT	2
3	1	160154	1207	89	N	G	NT	2
4	2	160470	1221	5	N	G	NT	1
5	3	160547	1224	10	N	G	NT	1
6	3	160403	1218	61	N	G	NT	2
7	3	160550	1224	81	N	G	NT	2
8	4	160128	1206	73	N	G	NT	2
9	4	160373	1217	93	N	G	ST	2
10	5	160084	1204	41	N	G	NT	1
11	6	160298	1213	51	N	G	NT	2
12	7	160183	1208	19	N	G	NT	1
13	7	160180	1208	93	N	G	ST	2
14	8	160423	1219	87	N	G	NT	2
15	9	160335	1215	48	N	G	NT	2
16	9	160327	1215	71	O	G	NT	2
17	10	160244	1211	32	N	G	NT	1
18	10	160252	1211	93	N	G	ST	2
19	11	160207	1209	62	N	G	NT	2
20	11	160200	1209	87	N	G	NT	2
21	12	160320	1214	31	N	G	NT	1
22	12	160221	1210	50	N	G	NT	2
23	13	160411	1218	32	N	G	NT	1
24	13	160405	1218	45	N	G	NT	1
25	13	160380	1217	80	N	G	NT	2
26	14	160368	1216	18	P	G	NT	1
27	14	160481	1221	57	N	G	NT	2
28	15	160160	1207	90	N	G	NT	2
29	15	160154	1207	96	N	G	ST	2
30	16	160547	1224	42	N	G	NT	1
31	16	160138	1206	56	N	G	NT	2
32	16	160137	1206	93	N	G	ST	2
33	17	160262	1212	49	N	G	NT	2
34	17	160275	1212	96	N	G	ST	2
35	19	160248	1211	88	N	G	NT	2
36	20	160085	1204	37	N	G	NT	1
37	20	160086	1204	59	N	G	NT	2
38	20	160115	1205	76	N	G	NT	2
39	20	160114	1205	89	P	G	NT	2
40	21	160435	1219	34	N	G	NT	1
41	21	160436	1219	37	N	G	NT	1
42	21	160435	1219	48	N	G	NT	2
43	22	160067	1203	48	N	G	NT	2
44	22	160064	1203	61	N	G	NT	2
45	22	160067	1203	70	N	G	NT	2
46	23	160224	1210	40	P	G	NT	1
47	23	160216	1210	88	O	G	NT	2
48	25	160023	1201	43	N	G	NT	1
49	27	160544	1224	11	N	G	NT	1
50	27	160538	1224	20	N	G	NT	1
51	27	160547	1224	67	N	G	NT	2
52	29	160287	1213	54	N	G	NT	2
53	30	160182	1208	30	N	G	NT	1
54	31	160504	1222	10	N	G	NT	1
55	31	160500	1222	65	N	G	NT	2
56	32	160435	1219	7	N	G	NT	1
57	32	160089	1204	45	N	G	NT	1
58	32	160085	1204	87	N	G	NT	2
59	33	160226	1210	18	N	G	NT	1
60	33	160042	1202	60	N	G	NT	2
61	33	160226	1210	94	N	G	ST	2
62	34	160203	1209	19	N	G	NT	1
63	34	160320	1214	42	N	G	NT	1
64	34	160202	1209	47	N	G	NT	2
65	34	160322	1214	50	N	G	NT	2
66	34	160202	1209	55	N	G	NT	2
67	34	160322	1214	62	N	G	NT	2
68	35	160333	1215	85	N	G	NT	2
69	36	160063	1203	84	N	G	NT	2
70	37	160287	1213	39	N	R	NT	1
71	37	160476	1221	82	N	R	NT	2
72	38	160262	1212	75	O	R	NT	2
73	39	160321	1214	117	N	R	ET	2
74	40	160333	1215	2	P	R	NT	1
75	40	160160	1207	58	N	R	NT	2
76	40	160160	1207	61	N	R	NT	2
77	41	160165	1208	8	N	R	NT	1
78	41	160182	1208	43	N	R	NT	1
79	41	160173	1208	63	N	R	NT	2
80	42	160050	1203	10	N	R	NT	1
81	42	160065	1203	78	N	R	NT	2
82	42	160062	1203	80	N	R	NT	2
83	42	160058	1203	90	N	R	NT	2
84	43	160236	1211	33	N	R	NT	1
85	43	160252	1211	91	N	R	ST	2
86	44	160136	1206	4	P	R	NT	1
87	44	160219	1210	6	N	R	NT	1
88	44	160230	1210	18	N	R	NT	1
89	45	160297	1213	2	N	Q	NT	1
90	45	160316	1214	33	N	Q	NT	1
91	46	160063	1203	13	N	Q	NT	1
92	46	160539	1224	31	N	Q	NT	1
93	46	160550	1224	55	N	Q	NT	2
94	46	160551	1224	86	N	Q	NT	2
95	47	160177	1208	65	N	Q	NT	2
96	47	160235	1211	78	P	Q	NT	2
97	48	160159	1207	12	N	Q	NT	1
98	48	160155	1207	20	N	Q	NT	1
99	48	160154	1207	43	N	Q	NT	1
100	48	160160	1207	45	N	Q	NT	1
101	48	160230	1210	56	N	Q	NT	2
102	48	160159	1207	59	N	Q	NT	2
103	48	160221	1210	84	N	Q	NT	2
104	49	160322	1214	50	N	S	NT	2
105	49	160320	1214	53	N	S	NT	2
106	50	160160	1207	47	P	S	ST	1
107	50	160160	1207	72	N	S	NT	2
108	51	160319	1214	109	N	F	ET	2
\.


--
-- Data for Name: grade; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.grade (city) FROM stdin;
New York
New York
Moncow
California
London
Paris
Berlin
London
\.


--
-- Data for Name: grades; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.grades (id, grade_1, grade_2, grade_3) FROM stdin;
1	75	25	80
2	85	85	60
3	70	75	65
\.


--
-- Data for Name: hello; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hello (number_one, number_two, number_three) FROM stdin;
\.


--
-- Data for Name: hello1_1122; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hello1_1122 (abc) FROM stdin;
\.


--
-- Data for Name: hello1_12; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hello1_12 (abc) FROM stdin;
\.


--
-- Data for Name: hello_12; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hello_12 (abc) FROM stdin;
\.


--
-- Data for Name: item_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.item_mast (pro_id, pro_name, pro_price, pro_com) FROM stdin;
101	Mother Board	3200.00	15
102	Key \n\nBoard	450.00	16
103	ZIP \n\ndrive	250.00	14
104	Speaker	550.00	16
105	Monitor	5000.00	11
106	DVD \n\ndrive	900.00	12
107	CD \n\ndrive	800.00	12
108	Printer	2600.00	13
109	Refill cartridge	350.00	13
110	Mouse	250.00	12
\.


--
-- Data for Name: job_grades; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.job_grades (grade_level, lowest_sal, highest_sal) FROM stdin;
A	1000	2999
B	3000	5999
C	6000	9999
D	10000	14999
E	15000	24999
F	25000	40000
\.


--
-- Data for Name: job_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.job_history (employee_id, start_date, end_date, job_id, department_id) FROM stdin;
201	2004-02-17	2007-12-19	MK_REP	20
200	2002-07-01	2006-12-31	AC_ACCOUNT	90
200	1995-09-17	2001-06-17	AD_ASST	90
176	2007-01-01	2007-12-31	SA_MAN	80
176	2006-03-24	2006-12-31	SA_REP	80
122	2007-01-01	2007-12-31	ST_CLERK	50
114	2006-03-24	2007-12-31	ST_CLERK	50
102	2001-01-13	2006-07-24	IT_PROG	60
101	2001-10-28	2005-03-15	AC_MGR	110
101	1997-09-21	2001-10-27	AC_ACCOUNT	110
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jobs (job_id, job_title, min_salary, max_salary) FROM stdin;
AD_PRES	President	20000	40000
AD_VP	Administration Vice President	15000	30000
AD_ASST	Administration Assistant	3000	6000
FI_MGR	Finance Manager	8200	16000
FI_ACCOUNT	Accountant	4200	9000
AC_MGR	Accounting Manager	8200	16000
AC_ACCOUNT	Public Accountant	4200	9000
SA_MAN	Sales Manager	10000	20000
SA_REP	Sales Representative	6000	12000
PU_MAN	Purchasing Manager	8000	15000
PU_CLERK	Purchasing Clerk	2500	5500
ST_MAN	Stock Manager	5500	8500
ST_CLERK	Stock Clerk	2000	5000
SH_CLERK	Shipping Clerk	2500	5500
IT_PROG	Programmer	4000	10000
MK_MAN	Marketing Manager	9000	15000
MK_REP	Marketing Representative	4000	9000
HR_REP	Human Resources Representative	4000	9000
PR_REP	Public Relations Representative	4500	10500
\.


--
-- Data for Name: kk; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kk (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5007	Paul Adam	Rome	0.13
5003	Lauson Hen	San Jose	0.12
\.


--
-- Data for Name: kkk; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kkk (name) FROM stdin;
James Hoog
Nail Knite
Pit Alex
Mc Lyon
Paul Adam
Lauson Hen
\.


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.locations (location_id, street_address, postal_code, city, state_province, country_id) FROM stdin;
1000	1297 Via Cola di Rie	989	Roma		IT
1100	93091 Calle della Testa	10934	Venice		IT
1200	2017 Shinjuku-ku	1689	Tokyo	Tokyo Prefecture	JP
1300	9450 Kamiya-cho	6823	Hiroshima		JP
1400	2014 Jabberwocky Rd	26192	Southlake	Texas	US
1500	2011 Interiors Blvd	99236	South San Francisco	California	US
1600	2007 Zagora St	50090	South Brunswick	New Jersey	US
1700	2004 Charade Rd	98199	Seattle	Washington	US
1800	147 Spadina Ave	M5V 2L7	Toronto	Ontario	CA
1900	6092 Boxwood St	YSW 9T2	Whitehorse	Yukon	CA
2000	40-5-12 Laogianggen	190518	Beijing		CN
2100	1298 Vileparle (E)	490231	Bombay	Maharashtra	IN
2200	12-98 Victoria Street	2901	Sydney	New South Wales	AU
2300	198 Clementi North	540198	Singapore		SG
2400	8204 Arthur St		London		UK
2500	"Magdalen Centre	 The Oxford 	OX9 9ZB	Oxford	Ox
2600	9702 Chester Road	9629850293	Stretford	Manchester	UK
2700	Schwanthalerstr. 7031	80925	Munich	Bavaria	DE
2800	Rua Frei Caneca 1360	01307-002	Sao Paulo	Sao Paulo	BR
2900	20 Rue des Corps-Saints	1730	Geneva	Geneve	CH
3000	Murtenstrasse 921	3095	Bern	BE	CH
3100	Pieter Breughelstraat 837	3029SK	Utrecht	Utrecht	NL
3200	Mariano Escobedo 9991	11932	Mexico City	"Distrito Federal	"
\.


--
-- Data for Name: londoncustomers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.londoncustomers (cust_name, city) FROM stdin;
Julian Green	London
Brad Guzan	London
\.


--
-- Data for Name: manufacturers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.manufacturers (code, name) FROM stdin;
\.


--
-- Data for Name: match_captain; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.match_captain (match_no, team_id, player_captain) FROM stdin;
1	1207	160140
1	1216	160349
2	1201	160013
2	1221	160467
3	1224	160539
3	1218	160401
4	1206	160136
4	1217	160373
5	1222	160494
5	1204	160076
6	1213	160297
6	1212	160267
7	1208	160163
7	1223	160515
8	1219	160424
8	1205	160110
9	1215	160331
9	1220	160459
10	1203	160062
10	1211	160231
11	1202	160028
11	1209	160202
12	1214	160322
12	1210	160222
13	1217	160373
13	1218	160401
14	1216	160349
14	1221	160467
15	1207	160140
15	1201	160004
16	1206	160136
16	1224	160539
17	1223	160515
17	1212	160267
18	1208	160163
18	1213	160297
19	1211	160231
19	1220	160459
20	1205	160110
20	1204	160076
21	1219	160424
21	1222	160494
22	1203	160062
22	1215	160331
23	1210	160222
23	1209	160202
24	1214	160322
24	1202	160028
25	1216	160349
25	1201	160004
26	1221	160467
26	1207	160140
27	1217	160386
27	1224	160539
28	1218	160401
28	1206	160120
29	1223	160520
29	1213	160297
30	1212	160267
30	1208	160163
31	1205	160093
31	1222	160494
32	1204	160076
32	1219	160424
33	1210	160222
33	1202	160028
34	1209	160202
34	1214	160322
35	1211	160235
35	1215	160328
36	1220	160459
36	1203	160062
37	1221	160467
37	1213	160297
38	1224	160539
38	1212	160267
39	1204	160076
39	1214	160322
40	1207	160140
40	1215	160328
41	1208	160163
41	1218	160401
42	1209	160202
42	1203	160062
43	1211	160231
43	1219	160424
44	1206	160136
44	1210	160222
45	1213	160297
45	1214	160322
46	1224	160539
46	1203	160062
47	1208	160163
47	1211	160231
48	1207	160140
48	1210	160222
49	1214	160322
49	1224	160539
50	1207	160140
50	1208	160180
51	1214	160322
51	1207	160140
\.


--
-- Data for Name: match_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.match_details (match_no, play_stage, team_id, win_lose, decided_by, goal_score, penalty_score, ass_ref, player_gk) FROM stdin;
1	G	1207	W	N	2	\N	80016	160140
1	G	1216	L	N	1	\N	80020	160348
2	G	1201	L	N	0	\N	80003	160001
2	G	1221	W	N	1	\N	80023	160463
3	G	1224	W	N	2	\N	80031	160532
3	G	1218	L	N	1	\N	80025	160392
4	G	1206	D	N	1	\N	80008	160117
4	G	1217	D	N	1	\N	80019	160369
5	G	1222	L	N	0	\N	80011	160486
5	G	1204	W	N	1	\N	80022	160071
6	G	1213	W	N	1	\N	80036	160279
6	G	1212	L	N	0	\N	80029	160256
7	G	1208	W	N	2	\N	80014	160163
7	G	1223	L	N	0	\N	80006	160508
8	G	1219	W	N	1	\N	80018	160416
8	G	1205	L	N	0	\N	80012	160093
9	G	1215	D	N	1	\N	80017	160324
9	G	1220	D	N	1	\N	80010	160439
10	G	1203	L	N	0	\N	80004	160047
10	G	1211	W	N	2	\N	80007	160231
11	G	1202	L	N	0	\N	80026	160024
11	G	1209	W	N	2	\N	80028	160187
12	G	1214	D	N	1	\N	80009	160302
12	G	1210	D	N	1	\N	80015	160208
13	G	1217	L	N	1	\N	80001	160369
13	G	1218	W	N	2	\N	80002	160392
14	G	1216	D	N	1	\N	80030	160348
14	G	1221	D	N	1	\N	80032	160463
15	G	1207	W	N	2	\N	80033	160140
15	G	1201	L	N	0	\N	80027	160001
16	G	1206	W	N	2	\N	80005	160117
16	G	1224	L	N	1	\N	80013	160531
17	G	1223	L	N	0	\N	80035	160508
17	G	1212	W	N	2	\N	80034	160256
18	G	1208	D	N	0	\N	80021	160163
18	G	1213	D	N	0	\N	80024	160278
19	G	1211	W	N	1	\N	80016	160231
19	G	1220	L	N	0	\N	80020	160439
20	G	1205	D	N	2	\N	80004	160093
20	G	1204	D	N	2	\N	80007	160071
21	G	1219	W	N	3	\N	80017	160416
21	G	1222	L	N	0	\N	80010	160486
22	G	1203	W	N	3	\N	80009	160047
22	G	1215	L	N	0	\N	80015	160324
23	G	1210	D	N	1	\N	80030	160208
23	G	1209	D	N	1	\N	80032	160187
24	G	1214	D	N	0	\N	80008	160302
24	G	1202	D	N	0	\N	80019	160024
25	G	1216	L	N	0	\N	80035	160348
25	G	1201	W	N	1	\N	80034	160001
26	G	1221	D	N	0	\N	80001	160463
26	G	1207	D	N	0	\N	80002	160140
27	G	1217	L	N	0	\N	80011	160369
27	G	1224	W	N	3	\N	80022	160531
28	G	1218	D	N	0	\N	80003	160392
28	G	1206	D	N	0	\N	80023	160117
29	G	1223	L	N	0	\N	80031	160508
29	G	1213	W	N	1	\N	80025	160278
30	G	1212	L	N	0	\N	80026	160256
30	G	1208	W	N	1	\N	80028	160163
31	G	1205	L	N	0	\N	80033	160093
31	G	1222	W	N	2	\N	80027	160486
32	G	1204	W	N	2	\N	80021	160071
32	G	1219	L	N	1	\N	80024	160416
33	G	1210	W	N	2	\N	80018	160208
33	G	1202	L	N	1	\N	80012	160024
34	G	1209	D	N	3	\N	80014	160187
34	G	1214	D	N	3	\N	80006	160302
35	G	1211	L	N	0	\N	80036	160233
35	G	1215	W	N	1	\N	80029	160324
36	G	1220	L	N	0	\N	80005	160439
36	G	1203	W	N	1	\N	80013	160047
37	R	1221	L	P	1	4	80004	160463
37	R	1213	W	P	1	5	80007	160278
38	R	1224	W	N	1	\N	80014	160531
38	R	1212	L	N	0	\N	80006	160256
39	R	1204	L	N	0	\N	80003	160071
39	R	1214	W	N	1	\N	80023	160302
40	R	1207	W	N	2	\N	80008	160140
40	R	1215	L	N	1	\N	80019	160324
41	R	1208	W	N	3	\N	80018	160163
41	R	1218	L	N	0	\N	80012	160392
42	R	1209	L	N	0	\N	80017	160187
42	R	1203	W	N	4	\N	80010	160047
43	R	1211	W	N	2	\N	80009	160231
43	R	1219	L	N	0	\N	80015	160416
44	R	1206	L	N	1	\N	80001	160117
44	R	1210	W	N	2	\N	80002	160208
45	Q	1213	L	P	1	3	80005	160278
45	Q	1214	W	P	1	5	80013	160302
46	Q	1224	W	N	3	\N	80001	160531
46	Q	1203	L	N	1	\N	80002	160047
47	Q	1208	W	P	1	6	80016	160163
47	Q	1211	L	P	1	5	80020	160231
48	Q	1207	W	N	5	\N	80021	160140
48	Q	1210	L	N	2	\N	80024	160208
49	S	1214	W	N	2	\N	80011	160302
49	S	1224	L	N	0	\N	80022	160531
50	S	1207	W	N	2	\N	80008	160140
50	S	1208	L	N	1	\N	80019	160163
51	F	1214	W	N	1	\N	80004	160302
51	F	1207	L	N	0	\N	80007	160140
\.


--
-- Data for Name: match_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.match_mast (match_no, play_stage, play_date, results, decided_by, goal_score, venue_id, referee_id, audence, plr_of_match, stop1_sec, stop2_sec) FROM stdin;
1	G	2016-06-11	WIN  	N	2-1  	20008	70007	75113	160154	131	242
2	G	2016-06-11	WIN  	N	0-1  	20002	70012	33805	160476	61	182
3	G	2016-06-11	WIN  	N	2-1  	20001	70017	37831	160540	64	268
4	G	2016-06-12	DRAW 	N	1-1  	20005	70011	62343	160128	0	185
5	G	2016-06-12	WIN  	N	0-1  	20007	70006	43842	160084	125	325
6	G	2016-06-12	WIN  	N	1-0  	20006	70014	33742	160291	2	246
7	G	2016-06-13	WIN  	N	2-0  	20003	70002	43035	160176	89	188
8	G	2016-06-13	WIN  	N	1-0  	20010	70009	29400	160429	360	182
9	G	2016-06-13	DRAW 	N	1-1  	20008	70010	73419	160335	67	194
10	G	2016-06-14	WIN  	N	0-2  	20004	70005	55408	160244	63	189
11	G	2016-06-14	WIN  	N	0-2  	20001	70018	34424	160197	61	305
12	G	2016-06-15	DRAW 	N	1-1  	20009	70004	38742	160320	15	284
13	G	2016-06-15	WIN  	N	1-2  	20003	70001	38989	160405	62	189
14	G	2016-06-15	DRAW 	N	1-1  	20007	70015	43576	160477	74	206
15	G	2016-06-16	WIN  	N	2-0  	20005	70013	63670	160154	71	374
16	G	2016-06-16	WIN  	N	2-1  	20002	70003	34033	160540	62	212
17	G	2016-06-16	WIN  	N	0-2  	20004	70016	51043	160262	7	411
18	G	2016-06-17	DRAW 	N	0-0  	20008	70008	73648	160165	6	208
19	G	2016-06-17	WIN  	N	1-0  	20010	70007	29600	160248	2	264
20	G	2016-06-17	DRAW 	N	2-2  	20009	70005	38376	160086	71	280
21	G	2016-06-18	WIN  	N	3-0  	20006	70010	33409	160429	84	120
22	G	2016-06-18	WIN  	N	3-0  	20001	70004	39493	160064	11	180
23	G	2016-06-18	DRAW 	N	1-1  	20005	70015	60842	160230	61	280
24	G	2016-06-19	DRAW 	N	0-0  	20007	70011	44291	160314	3	200
25	G	2016-06-20	WIN  	N	0-1  	20004	70016	49752	160005	125	328
26	G	2016-06-20	DRAW 	N	0-0  	20003	70001	45616	160463	60	122
27	G	2016-06-21	WIN  	N	0-3  	20010	70006	28840	160544	62	119
28	G	2016-06-21	DRAW 	N	0-0  	20009	70012	39051	160392	62	301
29	G	2016-06-21	WIN  	N	0-1  	20005	70017	58874	160520	29	244
30	G	2016-06-21	WIN  	N	0-1  	20007	70018	44125	160177	21	195
31	G	2016-06-22	WIN  	N	0-2  	20002	70013	32836	160504	60	300
32	G	2016-06-22	WIN  	N	2-1  	20001	70008	37245	160085	70	282
33	G	2016-06-22	WIN  	N	2-1  	20008	70009	68714	160220	7	244
34	G	2016-06-22	DRAW 	N	3-3  	20004	70002	55514	160322	70	185
35	G	2016-06-23	WIN  	N	0-1  	20003	70014	44268	160333	79	221
36	G	2016-06-23	WIN  	N	0-1  	20006	70003	34011	160062	63	195
37	R	2016-06-25	WIN  	P	1-1  	20009	70005	38842	160476	126	243
38	R	2016-06-25	WIN  	N	1-0  	20007	70002	44342	160547	5	245
39	R	2016-06-26	WIN  	N	0-1  	20002	70012	33523	160316	61	198
40	R	2016-06-26	WIN  	N	2-1  	20004	70011	56279	160160	238	203
41	R	2016-06-26	WIN  	N	3-0  	20003	70009	44312	160173	62	124
42	R	2016-06-27	WIN  	N	0-4  	20010	70010	28921	160062	3	133
43	R	2016-06-27	WIN  	N	2-0  	20008	70004	76165	160235	63	243
44	R	2016-06-28	WIN  	N	1-2  	20006	70001	33901	160217	5	199
45	Q	2016-07-01	WIN  	P	1-1  	20005	70003	62940	160316	58	181
46	Q	2016-07-02	WIN  	N	3-1  	20003	70001	45936	160550	14	182
47	Q	2016-07-03	WIN  	P	1-1  	20001	70007	38764	160163	63	181
48	Q	2016-07-04	WIN  	N	5-2  	20008	70008	76833	160159	16	125
49	S	2016-07-07	WIN  	N	2-0  	20004	70006	55679	160322	2	181
50	S	2016-07-08	WIN  	N	2-0  	20005	70011	64078	160160	126	275
51	F	2016-07-11	WIN  	N	1-0  	20008	70005	75868	160307	161	181
\.


--
-- Data for Name: maxim00; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.maxim00 (num, name) FROM stdin;
\.


--
-- Data for Name: maximum; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.maximum (num, name) FROM stdin;
\.


--
-- Data for Name: maximum00; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.maximum00 (num, name) FROM stdin;
\.


--
-- Data for Name: maximum899; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.maximum899 (num, name) FROM stdin;
\.


--
-- Data for Name: medication; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.medication (code, name, brand, description) FROM stdin;
1	Procrastin-X	X	N/A
2	Thesisin	Foo Labs	N/A
3	Awakin	Bar Laboratories	N/A
4	Crescavitin	Baz Industries	N/A
5	Melioraurin	Snafu Pharmaceuticals	N/A
\.


--
-- Data for Name: movie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movie (mov_id, mov_title, mov_year, mov_time, mov_lang, mov_dt_rel, mov_rel_country) FROM stdin;
901	Vertigo                                           	1958	128	English        	1958-08-24	UK   
902	The Innocents                                     	1961	100	English        	1962-02-19	SW   
903	Lawrence of Arabia                                	1962	216	English        	1962-12-11	UK   
904	The Deer Hunter                                   	1978	183	English        	1979-03-08	UK   
905	Amadeus                                           	1984	160	English        	1985-01-07	UK   
906	Blade Runner                                      	1982	117	English        	1982-09-09	UK   
907	Eyes Wide Shut                                    	1999	159	English        	\N	UK   
908	The Usual Suspects                                	1995	106	English        	1995-08-25	UK   
909	Chinatown                                         	1974	130	English        	1974-08-09	UK   
910	Boogie Nights                                     	1997	155	English        	1998-02-16	UK   
911	Annie Hall                                        	1977	93	English        	1977-04-20	USA  
912	Princess Mononoke                                 	1997	134	Japanese       	2001-10-19	UK   
913	The Shawshank Redemption                          	1994	142	English        	1995-02-17	UK   
914	American Beauty                                   	1999	122	English        	\N	UK   
915	Titanic                                           	1997	194	English        	1998-01-23	UK   
916	Good Will Hunting                                 	1997	126	English        	1998-06-03	UK   
917	Deliverance                                       	1972	109	English        	1982-10-05	UK   
918	Trainspotting                                     	1996	94	English        	1996-02-23	UK   
919	The Prestige                                      	2006	130	English        	2006-11-10	UK   
920	Donnie Darko                                      	2001	113	English        	\N	UK   
921	Slumdog Millionaire                               	2008	120	English        	2009-01-09	UK   
922	Aliens                                            	1986	137	English        	1986-08-29	UK   
923	Beyond the Sea                                    	2004	118	English        	2004-11-26	UK   
924	Avatar                                            	2009	162	English        	2009-12-17	UK   
926	Seven Samurai                                     	1954	207	Japanese       	1954-04-26	JP   
927	Spirited Away                                     	2001	125	Japanese       	2003-09-12	UK   
928	Back to the Future                                	1985	116	English        	1985-12-04	UK   
925	Braveheart                                        	1995	178	English        	1995-09-08	UK   
\.


--
-- Data for Name: movie_cast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movie_cast (act_id, mov_id, role) FROM stdin;
101	901	John Scottie Ferguson         
102	902	Miss Giddens                  
103	903	T.E. Lawrence                 
104	904	Michael                       
105	905	Antonio Salieri               
106	906	Rick Deckard                  
107	907	Alice Harford                 
108	908	McManus                       
110	910	Eddie Adams                   
111	911	Alvy Singer                   
112	912	San                           
113	913	Andy Dufresne                 
114	914	Lester Burnham                
115	915	Rose DeWitt Bukater           
116	916	Sean Maguire                  
117	917	Ed                            
118	918	Renton                        
120	920	Elizabeth Darko               
121	921	Older Jamal                   
122	922	Ripley                        
114	923	Bobby Darin                   
109	909	J.J. Gittes                   
119	919	Alfred Borden                 
\.


--
-- Data for Name: movie_direction; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movie_direction (dir_id, mov_id) FROM stdin;
201	901
202	902
203	903
204	904
205	905
206	906
207	907
208	908
209	909
210	910
211	911
212	912
213	913
214	914
215	915
216	916
217	917
218	918
219	919
220	920
218	921
215	922
221	923
\.


--
-- Data for Name: movie_genres; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movie_genres (mov_id, gen_id) FROM stdin;
922	1001
917	1002
903	1002
912	1003
911	1005
908	1006
913	1006
926	1007
928	1007
918	1007
921	1007
902	1008
923	1009
907	1010
927	1010
901	1010
914	1011
906	1012
904	1013
\.


--
-- Data for Name: my; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.my (customer_id, avg) FROM stdin;
3007	2400.6000000000000000
3008	250.4500000000000000
3002	2956.9533333333333333
3001	270.6500000000000000
3009	1295.4500000000000000
3004	1983.4300000000000000
3003	75.2900000000000000
3005	549.5000000000000000
\.


--
-- Data for Name: mytemptable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mytemptable (customer_id, avg) FROM stdin;
3007	2400.6000000000000000
3008	250.4500000000000000
3002	2956.9533333333333333
3001	270.6500000000000000
3009	1295.4500000000000000
3004	1983.4300000000000000
3003	75.2900000000000000
3005	549.5000000000000000
\.


--
-- Data for Name: mytest; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mytest (ord_num, ord_amount, ord_date, cust_code, agent_code) FROM stdin;
\.


--
-- Data for Name: mytest1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mytest1 (ord_num, ord_amount, ord_date, cust_code, agent_code) FROM stdin;
\.


--
-- Data for Name: new; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.new (city) FROM stdin;
New York
\.


--
-- Data for Name: new123; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.new123 ("Customer", city, "Salesman", commission) FROM stdin;
Nick Rimando	New York	James Hoog	0.15
Graham Zusi	California	Nail Knite	0.13
Brad Guzan	London	Pit Alex	0.11
Fabian Johns	Paris	Mc Lyon	0.14
Brad Davis	New York	James Hoog	0.15
Geoff Camero	Berlin	Lauson Hen	0.12
Julian Green	London	Nail Knite	0.13
Jozy Altidor	Moncow	Paul Adam	0.13
\.


--
-- Data for Name: new_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.new_table (salesman_id, name, city, commission) FROM stdin;
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5003	Lauson Hense	\N	0.12
5007	Paul Adam	Rome	0.13
\.


--
-- Data for Name: newsalesman; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.newsalesman (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5007	Paul Adam	Rome	0.13
5003	Lauson Hen	San Jose	0.12
\.


--
-- Data for Name: newtab; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.newtab (ord_no, purch_amt, ord_date, customer_id, salesman_id) FROM stdin;
70009	270.65	2012-09-10	3001	5005
70002	65.26	2012-10-05	3002	5001
70004	110.50	2012-08-17	3009	5003
70005	2400.60	2012-07-27	3007	5001
70008	5760.00	2012-09-10	3002	5001
70010	1983.43	2012-10-10	3004	5006
70003	2480.40	2012-10-10	3009	5003
70011	75.29	2012-08-17	3003	5007
70013	3045.60	2012-04-25	3002	5001
70001	150.50	2012-10-05	3005	5002
70007	948.50	2012-09-10	3005	5002
70012	250.45	2012-06-27	3008	5002
\.


--
-- Data for Name: newtable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.newtable (roomnumber, roomtype, blockfloor, blockcode, unavailable) FROM stdin;
101	Single	1	1	f
102	Single	1	1	f
103	Single	1	1	f
111	Single	1	2	f
112	Single	1	2	t
113	Single	1	2	f
121	Single	1	3	f
122	Single	1	3	f
123	Single	1	3	f
201	Single	2	1	t
202	Single	2	1	f
203	Single	2	1	f
211	Single	2	2	f
212	Single	2	2	f
213	Single	2	2	t
221	Single	2	3	f
222	Single	2	3	f
223	Single	2	3	f
301	Single	3	1	f
302	Single	3	1	t
303	Single	3	1	f
311	Single	3	2	f
312	Single	3	2	f
313	Single	3	2	f
321	Single	3	3	t
322	Single	3	3	f
323	Single	3	3	f
401	Single	4	1	f
402	Single	4	1	t
403	Single	4	1	f
411	Single	4	2	f
412	Single	4	2	f
413	Single	4	2	f
421	Single	4	3	t
422	Single	4	3	f
423	Single	4	3	f
\.


--
-- Data for Name: nobel_win; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nobel_win (year, subject, winner, country, category) FROM stdin;
1970	Physics                  	Hannes Alfven                                	Sweden                   	Scientist                
1970	Physics                  	Louis Neel                                   	France                   	Scientist                
1970	Chemistry                	Luis Federico Leloir                         	France                   	Scientist                
1970	Physiology               	Julius Axelrod                               	USA                      	Scientist                
1970	Physiology               	Ulf von Euler                                	Sweden                   	Scientist                
1970	Physiology               	Bernard Katz                                 	Germany                  	Scientist                
1970	Literature               	Aleksandr Solzhenitsyn                       	Russia                   	Linguist                 
1970	Economics                	Paul Samuelson                               	USA                      	Economist                
1971	Physics                  	Dennis Gabor                                 	Hungary                  	Scientist                
1971	Chemistry                	Gerhard Herzberg                             	Germany                  	Scientist                
1971	Peace                    	Willy Brandt                                 	Germany                  	Chancellor               
1971	Literature               	Pablo Neruda                                 	Chile                    	Linguist                 
1971	Economics                	Simon Kuznets                                	Russia                   	Economist                
1978	Peace                    	Anwar al-Sadat                               	Egypt                    	President                
1978	Peace                    	Menachem Begin                               	Israel                   	Prime Minister           
1994	Peace                    	Yitzhak Rabin                                	Israel                   	Prime Minister           
1987	Physics                  	Johannes Georg Bednorz                       	Germany                  	Scientist                
1987	Chemistry                	Donald J. Cram                               	USA                      	Scientist                
1987	Chemistry                	Jean-Marie Lehn                              	France                   	Scientist                
1987	Physiology               	Susumu Tonegawa                              	Japan                    	Scientist                
1987	Literature               	Joseph Brodsky                               	Russia                   	Linguist                 
1987	Economics                	Robert Solow                                 	USA                      	Economist                
1994	Literature               	Kenzaburo Oe                                 	Japan                    	Linguist                 
1994	Economics                	Reinhard Selten                              	Germany                  	Economist                
\.


--
-- Data for Name: nros; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nros (uno, dos) FROM stdin;
\.


--
-- Data for Name: nuevo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nuevo (city) FROM stdin;
New York
\.


--
-- Data for Name: numbers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.numbers (one, two, three) FROM stdin;
\.


--
-- Data for Name: numeri; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.numeri (id, data, decimali) FROM stdin;
\.


--
-- Data for Name: numeros; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.numeros (uno, dos) FROM stdin;
\.


--
-- Data for Name: nurse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nurse (employeeid, name, "position", registered, ssn) FROM stdin;
101	Carla Espinosa	Head Nurse	t	111111110
102	Laverne Roberts	Nurse	t	222222220
103	Paul Flowers	Nurse	f	333333330
\.


--
-- Data for Name: oi; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.oi (customer_id, avg) FROM stdin;
3007	2400.6000000000000000
3008	250.4500000000000000
3002	2956.9533333333333333
3001	270.6500000000000000
3009	1295.4500000000000000
3004	1983.4300000000000000
3003	75.2900000000000000
3005	549.5000000000000000
\.


--
-- Data for Name: on_call; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.on_call (nurse, blockfloor, blockcode, oncallstart, oncallend) FROM stdin;
101	1	1	2008-11-04 11:00:00	2008-11-04 19:00:00
101	1	2	2008-11-04 11:00:00	2008-11-04 19:00:00
102	1	3	2008-11-04 11:00:00	2008-11-04 19:00:00
103	1	1	2008-11-04 19:00:00	2008-11-05 03:00:00
103	1	2	2008-11-04 19:00:00	2008-11-05 03:00:00
103	1	3	2008-11-04 19:00:00	2008-11-05 03:00:00
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (ord_no, purch_amt, ord_date, customer_id, salesman_id) FROM stdin;
70009	270.65	2012-09-10	3001	5005
70002	65.26	2012-10-05	3002	5001
70004	110.50	2012-08-17	3009	5003
70005	2400.60	2012-07-27	3007	5001
70008	5760.00	2012-09-10	3002	5001
70010	1983.43	2012-10-10	3004	5006
70003	2480.40	2012-10-10	3009	5003
70011	75.29	2012-08-17	3003	5007
70013	3045.60	2012-04-25	3002	5001
70001	150.50	2012-10-05	3005	5002
70007	948.50	2012-09-10	3005	5002
70012	250.45	2012-06-27	3008	5002
\.


--
-- Data for Name: orozco; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orozco (city) FROM stdin;
New York
\.


--
-- Data for Name: partest1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.partest1 (ord_num, ord_amount, ord_date, cust_code, agent_code) FROM stdin;
\.


--
-- Data for Name: participant; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.participant (participant_id, part_name) FROM stdin;
\.


--
-- Data for Name: participants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.participants (participant_id, part_name) FROM stdin;
\.


--
-- Data for Name: patient; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patient (ssn, name, address, phone, insuranceid, pcp) FROM stdin;
100000001	John Smith	42 Foobar Lane	555-0256	68476213	1
100000002	Grace Ritchie	37 Snafu Drive	555-0512	36546321	2
100000003	Random J. Patient	101 Omgbbq Street	555-1204	65465421	2
100000004	Dennis Doe	1100 Foobaz Avenue	555-2048	68421879	3
\.


--
-- Data for Name: penalty_gk; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.penalty_gk (match_no, team_id, player_gk) FROM stdin;
37	1221	160463
37	1213	160278
45	1213	160278
45	1214	160302
47	1208	160163
47	1211	160231
\.


--
-- Data for Name: penalty_shootout; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.penalty_shootout (kick_id, match_no, team_id, player_id, score_goal, kick_no) FROM stdin;
1	37	1221	160467	Y	1
2	37	1213	160297	Y	2
3	37	1221	160477	N	3
4	37	1213	160298	Y	4
5	37	1221	160476	Y	5
6	37	1213	160281	Y	6
7	37	1221	160470	Y	7
8	37	1213	160287	Y	8
9	37	1221	160469	Y	9
10	37	1213	160291	Y	10
11	45	1214	160322	Y	1
12	45	1213	160297	Y	2
13	45	1214	160316	Y	3
14	45	1213	160298	Y	4
15	45	1214	160314	Y	5
16	45	1213	160281	Y	6
17	45	1214	160320	Y	7
18	45	1213	160287	N	8
19	45	1214	160321	Y	9
20	47	1211	160251	Y	1
21	47	1208	160176	Y	2
22	47	1211	160253	N	3
23	47	1208	160183	N	4
24	47	1211	160234	Y	5
25	47	1208	160177	N	6
26	47	1211	160252	N	7
27	47	1208	160173	Y	8
28	47	1211	160235	N	9
29	47	1208	160180	N	10
30	47	1211	160244	Y	11
31	47	1208	160168	Y	12
32	47	1211	160246	Y	13
33	47	1208	160169	Y	14
34	47	1211	160238	Y	15
35	47	1208	160165	Y	16
36	47	1211	160237	N	17
37	47	1208	160166	Y	18
\.


--
-- Data for Name: persons; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.persons (personid, lastname, firstname, address, city) FROM stdin;
\.


--
-- Data for Name: physician; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.physician (employeeid, name, "position", ssn) FROM stdin;
1	John Dorian	Staff Internist	111111111
2	Elliot Reid	Attending Physician	222222222
3	Christopher Turk	Surgical Attending Physician	333333333
4	Percival Cox	Senior Attending Physician	444444444
5	Bob Kelso	Head Chief of Medicine	555555555
6	Todd Quinlan	Surgical Attending Physician	666666666
7	John Wen	Surgical Attending Physician	777777777
8	Keith Dudemeister	MD Resident	888888888
9	Molly Clock	Attending Psychiatrist	999999999
\.


--
-- Data for Name: player_booked; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.player_booked (match_no, team_id, player_id, booking_time, sent_off, play_schedule, play_half) FROM stdin;
1	1216	160349	32	 	NT	1
1	1216	160355	45	 	NT	1
1	1207	160159	69	Y	NT	2
1	1216	160360	78	 	NT	2
2	1221	160470	14	 	NT	1
2	1201	160013	23	 	NT	1
2	1201	160013	36	 	NT	1
2	1201	160014	63	 	NT	2
2	1221	160472	66	 	NT	2
2	1201	160015	89	 	NT	2
2	1201	160009	93	 	NT	2
3	1218	160401	2	 	ST	2
3	1218	160406	31	 	NT	1
3	1218	160408	78	 	NT	2
3	1218	160411	80	 	NT	2
3	1218	160407	83	 	NT	2
4	1206	160120	62	 	NT	2
4	1217	160377	72	 	NT	2
5	1222	160505	31	 	NT	1
5	1222	160490	48	 	NT	2
5	1204	160077	80	 	NT	2
5	1222	160502	91	 	NT	2
6	1213	160290	65	 	NT	2
6	1212	160258	69	 	NT	2
6	1213	160284	89	 	NT	2
7	1223	160518	68	 	NT	2
8	1205	160100	61	 	NT	2
9	1215	160336	43	 	NT	1
9	1220	160445	61	 	NT	2
9	1215	160341	77	 	NT	2
10	1211	160236	65	 	NT	2
10	1211	160248	75	 	NT	2
10	1211	160235	78	 	NT	2
10	1211	160245	84	 	NT	2
10	1203	160057	93	 	NT	2
11	1202	160027	33	 	NT	1
11	1202	160027	66	Y	NT	2
11	1209	160204	80	 	NT	2
12	1210	160227	2	 	ST	2
12	1210	160221	55	 	NT	2
13	1218	160395	46	 	NT	2
14	1221	160480	2	 	ST	2
14	1216	160361	22	 	NT	1
14	1216	160357	24	 	NT	1
14	1216	160367	37	 	NT	1
14	1221	160477	50	 	NT	2
14	1216	160352	76	 	NT	2
15	1201	160015	55	 	NT	2
15	1201	160011	81	 	NT	2
15	1207	160152	88	 	NT	2
16	1224	160535	61	 	NT	2
17	1223	160528	40	 	NT	1
17	1212	160272	63	 	NT	2
17	1223	160523	67	 	NT	2
17	1212	160266	87	 	NT	2
17	1212	160259	90	 	NT	2
18	1208	160175	3	 	NT	1
18	1213	160294	3	 	ST	2
18	1208	160177	34	 	NT	1
18	1213	160293	45	 	NT	1
18	1213	160288	55	 	NT	2
18	1208	160165	67	 	NT	2
19	1211	160242	69	 	NT	2
19	1220	160447	89	 	NT	2
19	1211	160231	94	 	NT	2
20	1204	160080	14	 	NT	1
20	1205	160101	72	 	NT	2
20	1204	160081	74	 	NT	2
20	1204	160078	88	 	NT	2
21	1219	160424	2	 	NT	1
21	1222	160504	9	 	NT	1
21	1222	160500	41	 	NT	1
22	1215	160334	42	 	NT	1
22	1203	160056	49	 	NT	2
23	1209	160199	2	 	ST	2
23	1210	160229	42	 	NT	1
23	1210	160227	75	 	NT	2
23	1210	160216	77	 	NT	2
23	1209	160192	81	 	NT	2
23	1209	160197	83	 	NT	2
24	1202	160028	6	 	NT	1
24	1214	160321	31	 	NT	1
24	1214	160307	40	 	NT	1
24	1202	160037	47	 	NT	2
24	1202	160029	78	 	NT	2
24	1202	160042	86	 	NT	2
25	1201	160012	6	 	NT	1
25	1216	160353	54	 	NT	2
25	1201	160017	85	 	NT	2
25	1216	160356	85	 	NT	2
25	1216	160364	91	 	NT	2
25	1201	160007	95	 	NT	2
26	1207	160147	25	 	NT	1
26	1207	160145	83	 	NT	2
27	1224	160551	16	 	NT	1
27	1217	160383	64	 	NT	2
28	1218	160409	24	 	NT	1
28	1206	160119	52	 	NT	2
29	1223	160520	25	 	NT	1
29	1223	160513	38	 	NT	1
29	1213	160290	60	 	NT	2
31	1222	160491	35	 	NT	1
31	1205	160108	36	 	NT	1
31	1205	160107	39	Y	NT	1
31	1222	160490	50	 	NT	2
31	1205	160112	87	 	NT	2
32	1204	160087	29	 	NT	1
32	1204	160079	70	 	NT	2
32	1204	160076	70	 	NT	2
32	1204	160085	88	 	NT	2
33	1210	160218	36	 	NT	1
33	1210	160230	51	 	NT	2
33	1202	160045	70	 	NT	2
33	1210	160220	78	 	NT	2
33	1210	160208	82	 	NT	2
34	1209	160190	13	 	NT	1
34	1209	160191	28	 	NT	1
34	1209	160203	34	 	NT	1
34	1209	160202	56	 	NT	2
35	1211	160233	39	 	NT	1
35	1215	160343	39	 	NT	1
35	1215	160332	73	 	NT	2
35	1211	160234	78	 	NT	2
35	1211	160253	87	 	NT	2
35	1211	160251	93	 	NT	2
36	1203	160064	1	 	ST	1
36	1203	160055	30	 	NT	1
36	1220	160451	72	 	NT	2
37	1221	160470	55	 	NT	2
37	1213	160282	58	 	NT	2
38	1212	160266	44	 	NT	1
38	1224	160538	58	 	NT	2
38	1212	160267	67	 	NT	2
38	1224	160544	92	 	NT	2
39	1214	160318	78	 	NT	2
40	1215	160328	25	 	NT	1
40	1207	160152	27	 	NT	1
40	1215	160334	41	 	NT	1
40	1207	160147	44	 	NT	1
40	1215	160329	66	Y	NT	2
40	1215	160343	72	 	NT	2
41	1218	160407	2	 	ST	2
41	1218	160401	13	 	NT	1
41	1208	160169	46	 	NT	2
41	1208	160168	67	 	NT	2
42	1209	160192	34	 	NT	1
42	1209	160194	47	 	NT	2
42	1209	160196	61	 	NT	2
42	1203	160056	67	 	NT	2
42	1203	160065	89	 	NT	2
42	1203	160061	91	 	NT	2
42	1209	160207	92	 	NT	2
43	1219	160431	2	 	ST	2
43	1211	160238	24	 	NT	1
43	1219	160436	41	 	NT	1
43	1211	160252	54	 	NT	2
43	1211	160245	89	 	NT	2
43	1219	160427	89	 	NT	2
43	1219	160421	89	 	NT	2
44	1210	160208	38	 	NT	1
44	1206	160137	47	 	NT	2
44	1210	160222	65	 	NT	2
45	1214	160318	2	 	ST	2
45	1213	160282	42	 	NT	1
45	1213	160281	66	 	NT	2
45	1214	160310	70	 	NT	2
45	1213	160290	89	 	NT	2
46	1224	160535	5	 	NT	1
46	1224	160533	16	 	NT	1
46	1224	160536	24	 	NT	1
46	1203	160061	59	 	NT	2
46	1224	160544	75	 	NT	2
46	1203	160050	85	 	NT	2
47	1211	160247	56	 	NT	2
47	1211	160238	57	 	NT	2
47	1211	160246	59	 	NT	2
47	1208	160168	90	 	NT	2
47	1208	160180	112	 	NT	2
48	1210	160221	58	 	NT	2
48	1207	160149	75	 	NT	2
49	1224	160540	8	 	NT	1
49	1224	160533	62	 	NT	2
49	1214	160303	71	 	NT	2
49	1214	160322	72	 	NT	2
49	1224	160547	88	 	NT	2
50	1208	160177	1	 	ST	1
50	1208	160172	36	 	NT	1
50	1207	160143	43	 	NT	1
50	1208	160180	45	 	NT	1
50	1208	160173	50	 	NT	2
50	1207	160152	75	 	NT	2
51	1214	160304	34	 	NT	1
51	1214	160313	62	 	NT	2
51	1207	160149	80	 	NT	2
51	1214	160308	95	 	ET	1
51	1207	160153	97	 	ET	1
51	1214	160318	98	 	ET	1
51	1207	160145	107	 	ET	2
51	1207	160155	115	 	ET	2
51	1214	160306	119	 	ET	2
51	1214	160302	122	 	ET	2
\.


--
-- Data for Name: player_in_out; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.player_in_out (match_no, team_id, player_id, in_out, time_in_out, play_schedule, play_half) FROM stdin;
1	1207	160151	I	66	NT	2
1	1207	160160	O	66	NT	2
1	1207	160161	I	77	NT	2
1	1207	160161	O	77	NT	2
1	1207	160157	I	2	ST	2
1	1207	160154	O	2	ST	2
1	1216	160365	I	61	NT	2
1	1216	160366	O	61	NT	2
1	1216	160357	I	72	NT	2
1	1216	160363	O	72	NT	2
1	1216	160364	I	82	NT	2
1	1216	160360	O	82	NT	2
2	1201	160014	I	62	NT	2
2	1201	160019	O	62	NT	2
2	1201	160021	I	74	NT	2
2	1201	160018	O	74	NT	2
2	1201	160022	I	82	NT	2
2	1201	160023	O	82	NT	2
2	1221	160480	I	62	NT	2
2	1221	160481	O	62	NT	2
2	1221	160475	I	76	NT	2
2	1221	160473	O	76	NT	2
2	1221	160474	I	88	NT	2
2	1221	160476	O	88	NT	2
3	1218	160413	I	59	NT	2
3	1218	160412	O	59	NT	2
3	1218	160403	I	60	NT	2
3	1218	160406	O	60	NT	2
3	1218	160410	I	83	NT	2
3	1218	160411	O	83	NT	2
3	1224	160543	I	69	NT	2
3	1224	160541	O	69	NT	2
3	1224	160550	I	71	NT	2
3	1224	160546	O	71	NT	2
3	1224	160537	I	88	NT	2
3	1224	160544	O	88	NT	2
4	1206	160133	I	78	NT	2
4	1206	160136	O	78	NT	2
4	1206	160131	I	87	NT	2
4	1206	160132	O	87	NT	2
4	1217	160386	I	77	NT	2
4	1217	160381	O	77	NT	2
4	1217	160380	I	80	NT	2
4	1217	160376	O	80	NT	2
4	1217	160383	I	85	NT	2
4	1217	160391	O	85	NT	2
5	1204	160090	I	87	NT	2
5	1204	160085	O	87	NT	2
5	1204	160075	I	90	NT	2
5	1204	160086	O	90	NT	2
5	1204	160092	I	3	ST	2
5	1204	160091	O	3	ST	2
5	1222	160502	I	46	NT	2
5	1222	160498	O	46	NT	2
5	1222	160504	I	65	NT	2
5	1222	160494	O	65	NT	2
5	1222	160506	I	69	NT	2
5	1222	160505	O	69	NT	2
6	1212	160266	I	46	NT	2
6	1212	160265	O	46	NT	2
6	1212	160276	I	66	NT	2
6	1212	160269	O	66	NT	2
6	1212	160272	I	76	NT	2
6	1212	160257	O	76	NT	2
6	1213	160289	I	78	NT	2
6	1213	160293	O	78	NT	2
6	1213	160288	I	80	NT	2
6	1213	160287	O	80	NT	2
6	1213	160294	I	88	NT	2
6	1213	160290	O	88	NT	2
7	1208	160179	I	78	NT	2
7	1208	160173	O	78	NT	2
7	1208	160180	I	90	NT	2
7	1208	160174	O	90	NT	2
7	1223	160528	I	66	NT	2
7	1223	160529	O	66	NT	2
7	1223	160526	I	73	NT	2
7	1223	160519	O	73	NT	2
8	1205	160113	I	75	NT	2
8	1205	160114	O	75	NT	2
8	1205	160112	I	86	NT	2
8	1205	160096	O	86	NT	2
8	1205	160107	I	88	NT	2
8	1205	160110	O	88	NT	2
8	1219	160433	I	62	NT	2
8	1219	160435	O	62	NT	2
8	1219	160432	I	70	NT	2
8	1219	160428	O	70	NT	2
8	1219	160437	I	82	NT	2
8	1219	160436	O	82	NT	2
9	1215	160337	I	64	NT	2
9	1215	160345	O	64	NT	2
9	1215	160342	I	78	NT	2
9	1215	160335	O	78	NT	2
9	1215	160338	I	85	NT	2
9	1215	160336	O	85	NT	2
9	1220	160444	I	45	NT	1
9	1220	160446	O	45	NT	1
9	1220	160458	I	59	NT	2
9	1220	160457	O	59	NT	2
9	1220	160449	I	86	NT	2
9	1220	160455	O	86	NT	2
10	1203	160068	I	62	NT	2
10	1203	160063	O	62	NT	2
10	1203	160069	I	73	NT	2
10	1203	160067	O	73	NT	2
10	1203	160058	I	76	NT	2
10	1203	160051	O	76	NT	2
10	1211	160238	I	58	NT	2
10	1211	160237	O	58	NT	2
10	1211	160250	I	75	NT	2
10	1211	160248	O	75	NT	2
10	1211	160245	I	78	NT	2
10	1211	160242	O	78	NT	2
11	1202	160041	I	59	NT	2
11	1202	160040	O	59	NT	2
11	1202	160046	I	65	NT	2
11	1202	160045	O	65	NT	2
11	1202	160042	I	77	NT	2
11	1202	160037	O	77	NT	2
11	1209	160206	I	69	NT	2
11	1209	160207	O	69	NT	2
11	1209	160200	I	79	NT	2
11	1209	160197	O	79	NT	2
11	1209	160195	I	89	NT	2
11	1209	160204	O	89	NT	2
12	1210	160227	I	81	NT	2
12	1210	160230	O	81	NT	2
12	1210	160211	I	90	NT	2
12	1210	160229	O	90	NT	2
12	1214	160316	I	71	NT	2
12	1214	160314	O	71	NT	2
12	1214	160321	I	76	NT	2
12	1214	160313	O	76	NT	2
12	1214	160319	I	84	NT	2
12	1214	160311	O	84	NT	2
13	1217	160380	I	46	NT	2
13	1217	160383	I	46	NT	2
13	1217	160376	O	46	NT	2
13	1217	160381	O	46	NT	2
13	1217	160386	I	75	NT	2
13	1217	160390	O	75	NT	2
13	1218	160413	I	67	NT	2
13	1218	160403	O	67	NT	2
13	1218	160402	I	72	NT	2
13	1218	160411	O	72	NT	2
13	1218	160412	I	80	NT	2
13	1218	160408	O	80	NT	2
14	1216	160358	I	46	NT	2
14	1216	160359	O	46	NT	2
14	1216	160350	I	62	NT	2
14	1216	160355	O	62	NT	2
14	1216	160366	I	84	NT	2
14	1216	160368	O	84	NT	2
14	1221	160480	I	63	NT	2
14	1221	160482	O	63	NT	2
14	1221	160466	I	83	NT	2
14	1221	160473	O	83	NT	2
14	1221	160483	I	90	NT	2
14	1221	160476	O	90	NT	2
15	1201	160018	I	71	NT	2
15	1201	160008	O	71	NT	2
15	1201	160019	I	74	NT	2
15	1201	160015	O	74	NT	2
15	1201	160010	I	85	NT	2
15	1201	160005	O	85	NT	2
15	1207	160155	I	46	NT	2
15	1207	160161	O	46	NT	2
15	1207	160160	I	68	NT	2
15	1207	160151	O	68	NT	2
15	1207	160158	I	77	NT	2
15	1207	160159	O	77	NT	2
16	1206	160138	I	46	NT	2
16	1206	160137	I	46	NT	2
16	1206	160134	O	46	NT	2
16	1206	160132	O	46	NT	2
16	1206	160135	I	73	NT	2
16	1206	160130	O	73	NT	2
16	1224	160541	I	67	NT	2
16	1224	160543	O	67	NT	2
16	1224	160546	I	72	NT	2
16	1224	160550	O	72	NT	2
17	1212	160275	I	69	NT	2
17	1212	160272	O	69	NT	2
17	1212	160270	I	84	NT	2
17	1212	160276	O	84	NT	2
17	1212	160265	I	87	NT	2
17	1212	160268	O	87	NT	2
17	1223	160529	I	71	NT	2
17	1223	160528	O	71	NT	2
17	1223	160516	I	76	NT	2
17	1223	160523	O	76	NT	2
17	1223	160526	I	83	NT	2
17	1223	160519	O	83	NT	2
18	1208	160179	I	66	NT	2
18	1208	160174	O	66	NT	2
18	1208	160182	I	71	NT	2
18	1208	160173	O	71	NT	2
18	1213	160289	I	76	NT	2
18	1213	160293	O	76	NT	2
18	1213	160290	I	80	NT	2
18	1213	160287	O	80	NT	2
18	1213	160294	I	87	NT	2
18	1213	160288	O	87	NT	2
19	1211	160253	I	60	NT	2
19	1211	160252	O	60	NT	2
19	1211	160245	I	74	NT	2
19	1211	160242	O	74	NT	2
19	1211	160247	I	85	NT	2
19	1211	160243	O	85	NT	2
19	1220	160455	I	79	NT	2
19	1220	160448	I	79	NT	2
19	1220	160449	O	79	NT	2
19	1220	160451	O	79	NT	2
19	1220	160457	I	85	NT	2
19	1220	160458	O	85	NT	2
20	1204	160083	I	62	NT	2
20	1204	160084	O	62	NT	2
20	1204	160075	I	90	NT	2
20	1204	160086	O	90	NT	2
20	1204	160079	I	2	ST	2
20	1204	160077	O	2	ST	2
20	1205	160115	I	67	NT	2
20	1205	160112	I	67	NT	2
20	1205	160113	O	67	NT	2
20	1205	160111	O	67	NT	2
20	1205	160114	I	86	NT	2
20	1205	160108	O	86	NT	2
21	1219	160426	I	64	NT	2
21	1219	160431	O	64	NT	2
21	1219	160430	I	71	NT	2
21	1219	160428	O	71	NT	2
21	1219	160418	I	81	NT	2
21	1219	160421	O	81	NT	2
21	1222	160497	I	46	NT	2
21	1222	160495	O	46	NT	2
21	1222	160499	I	62	NT	2
21	1222	160498	O	62	NT	2
21	1222	160503	I	70	NT	2
21	1222	160501	O	70	NT	2
22	1203	160063	I	57	NT	2
22	1203	160060	O	57	NT	2
22	1203	160068	I	64	NT	2
22	1203	160058	O	64	NT	2
22	1203	160066	I	83	NT	2
22	1203	160067	O	83	NT	2
22	1215	160337	I	62	NT	2
22	1215	160336	O	62	NT	2
22	1215	160338	I	71	NT	2
22	1215	160335	O	71	NT	2
22	1215	160342	I	79	NT	2
22	1215	160343	O	79	NT	2
23	1209	160201	I	66	NT	2
23	1209	160205	I	66	NT	2
23	1209	160206	O	66	NT	2
23	1209	160200	O	66	NT	2
23	1209	160207	I	84	NT	2
23	1209	160191	O	84	NT	2
23	1210	160223	I	65	NT	2
23	1210	160222	O	65	NT	2
23	1210	160227	I	69	NT	2
23	1210	160226	O	69	NT	2
23	1210	160228	I	84	NT	2
23	1210	160230	O	84	NT	2
24	1202	160042	I	65	NT	2
24	1202	160034	O	65	NT	2
24	1202	160044	I	85	NT	2
24	1202	160041	O	85	NT	2
24	1202	160033	I	87	NT	2
24	1202	160038	O	87	NT	2
24	1214	160313	I	71	NT	2
24	1214	160321	O	71	NT	2
24	1214	160319	I	83	NT	2
24	1214	160311	O	83	NT	2
24	1214	160315	I	89	NT	2
24	1214	160320	O	89	NT	2
25	1201	160020	I	59	NT	2
25	1201	160023	O	59	NT	2
25	1201	160018	I	77	NT	2
25	1201	160016	O	77	NT	2
25	1201	160013	I	83	NT	2
25	1201	160012	O	83	NT	2
25	1216	160362	I	46	NT	2
25	1216	160361	O	46	NT	2
25	1216	160364	I	57	NT	2
25	1216	160365	O	57	NT	2
25	1216	160366	I	68	NT	2
25	1216	160360	O	68	NT	2
26	1207	160154	I	63	NT	2
26	1207	160151	O	63	NT	2
26	1207	160153	I	77	NT	2
26	1207	160160	O	77	NT	2
26	1221	160482	I	74	NT	2
26	1221	160480	O	74	NT	2
26	1221	160474	I	79	NT	2
26	1221	160476	O	79	NT	2
26	1221	160466	I	86	NT	2
26	1221	160481	O	86	NT	2
27	1217	160372	I	46	NT	2
27	1217	160373	O	46	NT	2
27	1217	160381	I	52	NT	2
27	1217	160386	O	52	NT	2
27	1217	160384	I	70	NT	2
27	1217	160391	O	70	NT	2
27	1224	160541	I	74	NT	2
27	1224	160540	O	74	NT	2
27	1224	160542	I	76	NT	2
27	1224	160543	O	76	NT	2
27	1224	160548	I	83	NT	2
27	1224	160547	O	83	NT	2
28	1206	160136	I	56	NT	2
28	1206	160133	O	56	NT	2
28	1206	160126	I	61	NT	2
28	1206	160130	O	61	NT	2
28	1206	160134	I	76	NT	2
28	1206	160137	O	76	NT	2
28	1218	160402	I	57	NT	2
28	1218	160403	O	57	NT	2
28	1218	160396	I	67	NT	2
28	1218	160409	O	67	NT	2
28	1218	160400	I	78	NT	2
28	1218	160411	O	78	NT	2
29	1213	160287	I	46	NT	2
29	1213	160296	O	46	NT	2
29	1213	160288	I	71	NT	2
29	1213	160290	O	71	NT	2
29	1213	160295	I	3	ST	2
29	1213	160298	O	3	ST	2
29	1223	160519	I	73	NT	2
29	1223	160526	O	73	NT	2
29	1223	160524	I	1	ST	2
29	1223	160529	O	1	ST	2
30	1208	160179	I	55	NT	2
30	1208	160174	O	55	NT	2
30	1208	160180	I	69	NT	2
30	1208	160175	O	69	NT	2
30	1208	160167	I	76	NT	2
30	1208	160165	O	76	NT	2
30	1212	160274	I	59	NT	2
30	1212	160276	O	59	NT	2
30	1212	160270	I	70	NT	2
30	1212	160272	O	70	NT	2
30	1212	160275	I	84	NT	2
30	1212	160268	O	84	NT	2
31	1205	160115	I	57	NT	2
31	1205	160107	O	57	NT	2
31	1205	160112	I	71	NT	2
31	1205	160104	O	71	NT	2
31	1205	160105	I	90	NT	2
31	1205	160108	O	90	NT	2
31	1222	160498	I	61	NT	2
31	1222	160502	O	61	NT	2
31	1222	160499	I	69	NT	2
31	1222	160506	O	69	NT	2
31	1222	160505	I	90	NT	2
31	1222	160504	O	90	NT	2
32	1204	160083	I	82	NT	2
32	1204	160087	O	82	NT	2
32	1204	160088	I	90	NT	2
32	1204	160092	O	90	NT	2
32	1204	160090	I	2	ST	2
32	1204	160085	O	2	ST	2
32	1219	160426	I	60	NT	2
32	1219	160436	O	60	NT	2
32	1219	160433	I	67	NT	2
32	1219	160435	O	67	NT	2
32	1219	160432	I	84	NT	2
32	1219	160428	O	84	NT	2
33	1202	160042	I	46	NT	2
33	1202	160045	I	46	NT	2
33	1202	160031	O	46	NT	2
33	1202	160038	O	46	NT	2
33	1202	160039	I	78	NT	2
33	1202	160041	O	78	NT	2
33	1210	160211	I	71	NT	2
33	1210	160226	O	71	NT	2
33	1210	160219	I	80	NT	2
33	1210	160230	O	80	NT	2
33	1210	160214	I	86	NT	2
33	1210	160229	O	86	NT	2
34	1209	160188	I	46	NT	2
34	1209	160203	O	46	NT	2
34	1209	160204	I	71	NT	2
34	1209	160207	O	71	NT	2
34	1209	160200	I	83	NT	2
34	1209	160198	O	83	NT	2
34	1214	160316	I	46	NT	2
34	1214	160314	O	46	NT	2
34	1214	160321	I	61	NT	2
34	1214	160311	O	61	NT	2
34	1214	160313	I	81	NT	2
34	1214	160320	O	81	NT	2
35	1211	160237	I	60	NT	2
35	1211	160240	O	60	NT	2
35	1211	160251	I	74	NT	2
35	1211	160250	O	74	NT	2
35	1211	160249	I	81	NT	2
35	1211	160238	O	81	NT	2
35	1215	160338	I	70	NT	2
35	1215	160344	O	70	NT	2
35	1215	160335	I	77	NT	2
35	1215	160336	O	77	NT	2
35	1215	160340	I	90	NT	2
35	1215	160343	O	90	NT	2
36	1203	160068	I	71	NT	2
36	1203	160058	O	71	NT	2
36	1203	160066	I	87	NT	2
36	1203	160067	O	87	NT	2
36	1203	160069	I	2	ST	2
36	1203	160062	O	2	ST	2
36	1220	160458	I	63	NT	2
36	1220	160457	O	63	NT	2
36	1220	160448	I	70	NT	2
36	1220	160454	O	70	NT	2
36	1220	160450	I	82	NT	2
36	1220	160451	O	82	NT	2
37	1213	160289	I	101	ET	1
37	1213	160293	O	101	ET	1
37	1213	160294	I	104	ET	1
37	1213	160288	O	104	ET	1
37	1221	160480	I	58	NT	2
37	1221	160473	O	58	NT	2
37	1221	160479	I	70	NT	2
37	1221	160481	O	70	NT	2
37	1221	160474	I	77	NT	2
37	1221	160472	O	77	NT	2
38	1212	160276	I	69	NT	2
38	1212	160272	O	69	NT	2
38	1212	160275	I	79	NT	2
38	1212	160271	O	79	NT	2
38	1212	160270	I	84	NT	2
38	1212	160262	O	84	NT	2
38	1224	160550	I	55	NT	2
38	1224	160551	O	55	NT	2
38	1224	160546	I	63	NT	2
38	1224	160543	O	63	NT	2
39	1204	160092	I	110	ET	2
39	1204	160086	O	110	ET	2
39	1204	160090	I	120	ET	2
39	1204	160073	O	120	ET	2
39	1204	160089	I	88	NT	2
39	1204	160091	O	88	NT	2
39	1214	160313	I	117	ET	2
39	1214	160310	O	117	ET	2
39	1214	160316	I	50	NT	2
39	1214	160311	O	50	NT	2
39	1214	160321	I	87	NT	2
39	1214	160313	O	87	NT	2
40	1207	160151	I	46	NT	2
40	1207	160152	O	46	NT	2
40	1207	160158	I	73	NT	2
40	1207	160159	O	73	NT	2
40	1207	160157	I	2	ST	2
40	1207	160151	O	2	ST	2
40	1215	160345	I	65	NT	2
40	1215	160344	O	65	NT	2
40	1215	160331	I	68	NT	2
40	1215	160337	O	68	NT	2
40	1215	160335	I	71	NT	2
40	1215	160336	O	71	NT	2
41	1208	160167	I	72	NT	2
41	1208	160184	I	72	NT	2
41	1208	160165	O	72	NT	2
41	1208	160173	O	72	NT	2
41	1208	160180	I	76	NT	2
41	1208	160175	O	76	NT	2
41	1218	160404	I	46	NT	2
41	1218	160411	O	46	NT	2
41	1218	160414	I	64	NT	2
41	1218	160412	O	64	NT	2
41	1218	160399	I	84	NT	2
41	1218	160396	O	84	NT	2
42	1203	160058	I	70	NT	2
42	1203	160068	O	70	NT	2
42	1203	160065	I	76	NT	2
42	1203	160067	O	76	NT	2
42	1203	160061	I	81	NT	2
42	1203	160062	O	81	NT	2
42	1209	160196	I	46	NT	2
42	1209	160203	O	46	NT	2
42	1209	160205	I	75	NT	2
42	1209	160195	O	75	NT	2
42	1209	160201	I	79	NT	2
42	1209	160191	O	79	NT	2
43	1211	160245	I	54	NT	2
43	1211	160242	O	54	NT	2
43	1211	160251	I	82	NT	2
43	1211	160248	O	82	NT	2
43	1211	160237	I	84	NT	2
43	1211	160243	O	84	NT	2
43	1219	160433	I	46	NT	2
43	1219	160436	O	46	NT	2
43	1219	160434	I	70	NT	2
43	1219	160435	O	70	NT	2
43	1219	160437	I	81	NT	2
43	1219	160433	O	81	NT	2
44	1206	160133	I	46	NT	2
44	1206	160128	O	46	NT	2
44	1206	160138	I	60	NT	2
44	1206	160132	O	60	NT	2
44	1206	160135	I	87	NT	2
44	1206	160136	O	87	NT	2
44	1210	160211	I	76	NT	2
44	1210	160230	O	76	NT	2
44	1210	160219	I	89	NT	2
44	1210	160226	O	89	NT	2
45	1213	160289	I	98	ET	1
45	1213	160293	O	98	ET	1
45	1213	160290	I	82	NT	2
45	1213	160288	O	82	NT	2
45	1214	160313	I	96	ET	1
45	1214	160318	O	96	ET	1
45	1214	160314	I	70	NT	2
45	1214	160310	O	70	NT	2
45	1214	160321	I	80	NT	2
45	1214	160313	O	80	NT	2
46	1203	160061	I	46	NT	2
46	1203	160058	O	46	NT	2
46	1203	160068	I	75	NT	2
46	1203	160054	O	75	NT	2
46	1203	160065	I	83	NT	2
46	1203	160067	O	83	NT	2
46	1224	160542	I	78	NT	2
46	1224	160543	O	78	NT	2
46	1224	160551	I	80	NT	2
46	1224	160550	O	80	NT	2
46	1224	160534	I	90	NT	2
46	1224	160544	O	90	NT	2
47	1208	160180	I	16	NT	1
47	1208	160175	O	16	NT	1
47	1208	160173	I	72	NT	2
47	1208	160182	O	72	NT	2
47	1211	160253	I	120	ET	2
47	1211	160236	O	120	ET	2
47	1211	160237	I	86	NT	2
47	1211	160243	O	86	NT	2
47	1211	160251	I	108	NT	2
47	1211	160248	O	108	NT	2
48	1207	160158	I	60	NT	2
48	1207	160159	O	60	NT	2
48	1207	160146	I	72	NT	2
48	1207	160145	O	72	NT	2
48	1207	160151	I	80	NT	2
48	1207	160154	O	80	NT	2
48	1210	160214	I	46	NT	2
48	1210	160227	I	46	NT	2
48	1210	160220	O	46	NT	2
48	1210	160226	O	46	NT	2
48	1210	160228	I	83	NT	2
48	1210	160230	O	83	NT	2
49	1214	160311	I	74	NT	2
49	1214	160316	O	74	NT	2
49	1214	160314	I	79	NT	2
49	1214	160310	O	79	NT	2
49	1214	160321	I	86	NT	2
49	1214	160320	O	86	NT	2
49	1224	160551	I	58	NT	2
49	1224	160543	O	58	NT	2
49	1224	160548	I	63	NT	2
49	1224	160550	O	63	NT	2
49	1224	160546	I	66	NT	2
49	1224	160534	O	66	NT	2
50	1207	160152	I	71	NT	2
50	1207	160154	O	71	NT	2
50	1207	160158	I	78	NT	2
50	1207	160159	O	78	NT	2
50	1207	160150	I	2	ST	2
50	1207	160160	O	2	ST	2
50	1208	160170	I	61	NT	2
50	1208	160165	O	61	NT	2
50	1208	160174	I	67	NT	2
50	1208	160172	O	67	NT	2
50	1208	160178	I	79	NT	2
50	1208	160180	O	79	NT	2
51	1207	160161	I	110	ET	2
51	1207	160154	O	110	ET	2
51	1207	160151	I	58	NT	2
51	1207	160154	O	58	NT	2
51	1207	160158	I	78	NT	2
51	1207	160159	O	78	NT	2
51	1214	160321	I	25	NT	1
51	1214	160322	O	25	NT	1
51	1214	160314	I	66	NT	2
51	1214	160310	O	66	NT	2
51	1214	160319	I	79	NT	2
51	1214	160316	O	79	NT	2
\.


--
-- Data for Name: player_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.player_mast (player_id, team_id, jersey_no, player_name, posi_to_play, dt_of_bir, age, playing_club) FROM stdin;
160001	1201	1	Etrit Berisha 	GK	1989-03-10	27	Lazio
160008	1201	2	Andi Lila 	DF	1986-02-12	30	Giannina
160016	1201	3	Ermir Lenjani 	MF	1989-08-05	26	Nantes
160007	1201	4	Elseid Hysaj 	DF	1994-02-20	22	Napoli
160013	1201	5	Lorik Cana 	MF	1983-07-27	32	Nantes
160010	1201	6	Frederic Veseli 	DF	1992-11-20	23	Lugano
160004	1201	7	Ansi Agolli 	DF	1982-10-11	33	Qarabag
160012	1201	8	Migjen Basha 	MF	1987-01-05	29	Como
160017	1201	9	Ledian Memushaj 	MF	1986-12-17	29	Pescara
160023	1201	10	Armando Sadiku 	FD	1991-05-27	25	Vaduz
160022	1201	11	Shkelzen Gashi 	FD	1988-07-15	27	Colorado
160003	1201	12	Orges Shehi 	GK	1977-09-25	38	Skenderbeu
160015	1201	13	Burim Kukeli 	MF	1984-01-16	32	Zurich
160019	1201	14	Taulant Xhaka 	MF	1991-03-28	25	Basel
160009	1201	15	Mergim Mavraj 	DF	1986-06-09	30	Koln
160021	1201	16	Sokol Cikalleshi 	FD	1990-07-27	25	Istanbul Basaksehir
160006	1201	17	Naser Aliji 	DF	1993-12-27	22	Basel
160005	1201	18	Arlind Ajeti 	DF	1993-09-25	22	Frosinone
160020	1201	19	Bekim Balaj 	FD	1991-01-11	25	Rijeka
160014	1201	20	Ergys Kace 	MF	1993-07-08	22	PAOK
160018	1201	21	Odise Roshi 	MF	1991-05-22	25	Rijeka
160011	1201	22	Amir Abrashi 	MF	1990-03-27	26	Freiburg
160002	1201	23	Alban Hoxha 	GK	1987-11-23	28	Partizani
160024	1202	1	Robert Almer 	GK	1984-03-20	32	Austria Wien
160036	1202	2	Gyorgy Garics 	MF	1984-03-08	32	Darmstadt
160027	1202	3	Aleksandar Dragovic 	DF	1991-03-06	25	Dynamo Kyiv
160029	1202	4	Martin Hinteregger 	DF	1992-09-07	23	Monchengladbach
160028	1202	5	Christian Fuchs 	DF	1986-04-07	30	Leicester
160038	1202	6	Stefan Ilsanker 	MF	1989-05-18	27	Leipzig
160043	1202	7	Marko Arnautovic 	FD	1989-04-19	27	Stoke
160034	1202	8	David Alaba 	MF	1992-06-24	23	Bayern
160046	1202	9	Rubin Okotie 	FD	1987-06-06	29	1860 Munchen
160040	1202	10	Zlatko Junuzovic 	MF	1987-09-26	28	Bremen
160037	1202	11	Martin Harnik 	MF	1987-06-10	29	Stuttgart
160025	1202	12	Heinz Lindner 	GK	1990-07-17	25	Frankfurt
160032	1202	13	Markus Suttner 	DF	1987-04-16	29	Ingolstadt
160035	1202	14	Julian Baumgartlinger 	MF	1988-01-02	28	Mainz
160031	1202	15	Sebastian Prodl 	DF	1987-06-21	28	Watford
160033	1202	16	Kevin Wimmer 	DF	1992-11-15	23	Tottenham
160030	1202	17	Florian Klein 	DF	1986-11-17	29	Stuttgart
160042	1202	18	Alessandro Schopf 	MF	1994-02-07	22	Schalke
160044	1202	19	Lukas Hinterseer 	FD	1991-03-28	25	Ingolstadt
160041	1202	20	Marcel Sabitzer 	MF	1994-03-17	22	Leipzig
160045	1202	21	Marc Janko 	FD	1983-06-25	32	Basel
160039	1202	22	Jakob Jantscher 	MF	1989-01-08	27	Luzern
160026	1202	23	Ramazan Ozcan 	GK	1984-06-28	31	Ingolstadt
160047	1203	1	Thibaut Courtois 	GK	1992-05-11	24	Chelsea
160050	1203	2	Toby Alderweireld 	DF	1989-03-02	27	Tottenham
160056	1203	3	Thomas Vermaelen 	DF	1985-11-14	30	Barcelona
160063	1203	4	Radja Nainggolan 	MF	1988-05-04	28	Roma
160057	1203	5	Jan Vertonghen 	DF	1987-04-24	29	Tottenham
160064	1203	6	Axel Witsel 	MF	1989-01-12	27	Zenit
160059	1203	7	Kevin De Bruyne 	MF	1991-06-28	24	Man. City
160061	1203	8	Marouane Fellaini 	MF	1987-11-22	28	Man. United
160067	1203	9	Romelu Lukaku 	FD	1993-05-13	23	Everton
160062	1203	10	Eden Hazard 	MF	1991-01-07	25	Chelsea
160058	1203	11	Yannick Carrasco 	MF	1993-09-04	22	Atletico
160049	1203	12	Simon Mignolet 	GK	1988-08-06	27	Liverpool
160048	1203	13	Jean-Francois Gillet 	GK	1979-05-31	37	Mechelen
160068	1203	14	Dries Mertens 	FD	1987-05-06	29	Napoli
160052	1203	15	Jason Denayer 	DF	1995-06-28	20	Galatasaray
160055	1203	16	Thomas Meunier 	DF	1991-09-12	24	Club Brugge
160069	1203	17	Divock Origi 	FD	1995-04-18	21	Liverpool
160053	1203	18	Christian Kabasele 	DF	1991-02-24	25	Genk
160060	1203	19	Mousa Dembele 	MF	1987-07-16	28	Tottenham
160066	1203	20	Christian Benteke 	FD	1990-12-03	25	Liverpool
160054	1203	21	Jordan Lukaku 	DF	1994-07-25	21	Oostende
160065	1203	22	Michy Batshuayi 	FD	1993-10-02	22	Marseille
160051	1203	23	Laurent Ciman 	DF	1985-08-05	30	Montreal
160072	1204	1	Ivan Vargic 	GK	1987-03-15	29	Rijeka
160079	1204	2	Sime Vrsaljko 	DF	1992-01-10	24	Sassuolo
160077	1204	3	Ivan Strinic 	DF	1987-07-17	28	Napoli
160085	1204	4	Ivan PeriSic 	MF	1989-02-02	27	Internazionale
160073	1204	5	Vedran Corluka 	DF	1986-02-05	30	Lokomotiv Moskva
160074	1204	6	Tin Jedvaj 	DF	1995-11-28	20	Leverkusen
160086	1204	7	Ivan Rakitic 	MF	1988-03-10	28	Barcelona
160083	1204	8	Mateo Kovacic 	MF	1994-05-06	22	Real Madrid
160090	1204	9	Andrej Kramaric 	FD	1991-06-19	24	Hoffenheim
160084	1204	10	Luka Modric 	MF	1985-09-09	30	Real Madrid
160076	1204	11	Darijo Srna 	DF	1982-05-01	34	Shakhtar Donetsk
160070	1204	12	Lovre Kalinic 	GK	1990-04-03	26	Hajduk Split
160075	1204	13	Gordon Schildenfeld 	DF	1985-03-18	31	Dinamo Zagreb
160081	1204	14	Marcelo Brozovic 	MF	1992-11-16	23	Internazionale
160087	1204	15	Marko Rog 	MF	1995-07-19	20	Dinamo Zagreb
160089	1204	16	Nikola Kalinic 	FD	1988-01-05	28	Fiorentina
160091	1204	17	Mario Mandzukic 	FD	1986-05-21	30	Juventus
160082	1204	18	Ante Coric 	MF	1997-04-14	19	Dinamo Zagreb
160080	1204	19	Milan Badelj 	MF	1989-02-25	27	Fiorentina
160092	1204	20	Marko Pjaca 	FD	1995-05-06	21	Dinamo Zagreb
160078	1204	21	Domagoj Vida 	DF	1989-04-29	27	Dynamo Kyiv
160088	1204	22	Duje Cop 	FD	1990-02-01	26	Malaga
160071	1204	23	Danijel SubaSic 	GK	1984-10-27	31	Monaco
160093	1205	1	Petr Cech 	GK	1982-05-20	34	Arsenal
160098	1205	2	Pavel Kaderabek 	DF	1992-04-25	24	Hoffenheim
160099	1205	3	Michal Kadlec 	DF	1984-12-13	31	Fenerbahce
160096	1205	4	Theodor Gebre Selassie 	DF	1986-12-24	29	Bremen
160097	1205	5	Roman Hubnik 	DF	1984-06-06	32	Plzen
160101	1205	6	TomasSivok 	DF	1983-09-15	32	Bursaspor
160114	1205	7	TomasNecid 	FD	1989-08-13	26	Bursaspor
160100	1205	8	David Limbersky 	DF	1983-10-06	32	Plzen
160104	1205	9	Borek Dockal 	MF	1988-09-30	27	Sparta Praha
160110	1205	10	TomasRosicky 	MF	1980-10-04	35	Arsenal
160109	1205	11	Daniel Pudil 	MF	1985-09-27	30	Sheff. Wednesday
160115	1205	12	Milan Skoda 	FD	1986-01-16	30	Slavia Praha
160108	1205	13	Jaroslav PlaSil 	MF	1982-01-05	34	Bordeaux
160105	1205	14	Daniel Kolar 	MF	1985-10-27	30	Plzen
160107	1205	15	David Pavelka 	MF	1991-05-18	25	Kasimpasa
160095	1205	16	TomasVaclik 	GK	1989-03-29	27	Basel
160102	1205	17	Marek Suchy 	DF	1988-03-29	28	Basel
160112	1205	18	Josef Sural 	MF	1990-05-30	26	Sparta Praha
160106	1205	19	Ladislav Krejci 	MF	1992-07-05	23	Sparta Praha
160111	1205	20	Jiri Skalak 	MF	1992-03-12	24	Brighton
160113	1205	21	David Lafata 	FD	1981-09-18	34	Sparta Praha
160103	1205	22	Vladimir Darida 	MF	1990-08-08	25	Hertha
160094	1205	23	TomasKoubek 	GK	1992-08-26	23	Liberec
160117	1206	1	Joe Hart 	GK	1987-04-19	29	Man. City
160125	1206	2	Kyle Walker 	DF	1990-05-28	26	Tottenham
160122	1206	3	Danny Rose 	DF	1990-07-02	25	Tottenham
160131	1206	4	James Milner 	MF	1986-01-04	30	Liverpool
160120	1206	5	Gary Cahill 	DF	1985-12-19	30	Chelsea
160123	1206	6	Chris Smalling 	DF	1989-11-22	26	Man. United
160132	1206	7	Raheem Sterling 	MF	1994-12-08	21	Man. City
160130	1206	8	Adam Lallana 	MF	1988-05-10	28	Liverpool
160134	1206	9	Harry Kane 	FD	1993-07-28	22	Tottenham
160136	1206	10	Wayne Rooney 	FD	1985-10-24	30	Man. United
160138	1206	11	Jamie Vardy 	FD	1987-01-11	29	Leicester
160121	1206	12	Nathaniel Clyne 	DF	1991-04-05	25	Liverpool
160116	1206	13	Fraser Forster 	GK	1988-03-17	28	Southampton
160129	1206	14	Jordan Henderson 	MF	1990-06-17	26	Liverpool
160137	1206	15	Daniel Sturridge 	FD	1989-09-01	26	Liverpool
160124	1206	16	John Stones 	DF	1994-05-28	22	Everton
160128	1206	17	Eric Dier 	MF	1994-01-15	22	Tottenham
160133	1206	18	Jack Wilshere 	MF	1992-01-01	24	Arsenal
160127	1206	19	Ross Barkley 	MF	1993-12-05	22	Everton
160126	1206	20	Dele Alli 	MF	1996-04-11	20	Tottenham
160119	1206	21	Ryan Bertrand 	DF	1989-08-05	26	Southampton
160135	1206	22	Marcus Rashford 	FD	1997-10-31	18	Man. United
160118	1206	23	Tom Heaton 	GK	1986-04-15	30	Burnley
160140	1207	1	Hugo Lloris 	GK	1986-12-26	29	Tottenham
160144	1207	2	Christophe Jallet 	DF	1983-10-31	32	Lyon
160143	1207	3	Patrice Evra 	DF	1981-05-15	35	Juventus
160147	1207	4	Adil Rami 	DF	1985-12-27	30	Sevilla
160152	1207	5	NGolo Kante 	MF	1991-03-29	25	Leicester
160150	1207	6	Yohan Cabaye 	MF	1986-01-14	30	Crystal Palace
160160	1207	7	Antoine Griezmann 	FD	1991-03-21	25	Atletico
160154	1207	8	Dimitri Payet 	MF	1987-03-29	29	West Ham
160159	1207	9	Olivier Giroud 	FD	1986-09-30	29	Arsenal
160158	1207	10	Andre-Pierre Gignac 	FD	1985-12-05	30	Tigres
160161	1207	11	Anthony Martial 	FD	1995-12-05	20	Man. United
160156	1207	12	Morgan Schneiderlin 	MF	1989-11-08	26	Man. United
160146	1207	13	Eliaquim Mangala 	DF	1991-02-13	25	Man. City
160153	1207	14	Blaise Matuidi 	MF	1987-04-09	29	Paris
160155	1207	15	Paul Pogba 	MF	1993-03-15	23	Juventus
160141	1207	16	Steve Mandanda 	GK	1985-03-28	31	Marseille
160142	1207	17	Lucas Digne 	DF	1993-07-20	22	Roma
160157	1207	18	Moussa Sissoko 	MF	1989-08-16	26	Newcastle
160148	1207	19	Bacary Sagna 	DF	1983-02-14	33	Man. City
160151	1207	20	Kingsley Coman 	MF	1996-06-13	20	Bayern
160145	1207	21	Laurent Koscielny 	DF	1985-09-10	30	Arsenal
160149	1207	22	Samuel Umtiti 	DF	1993-11-14	22	Lyon
160139	1207	23	Benoit Costil 	GK	1987-07-03	28	Rennes
160163	1208	1	Manuel Neuer 	GK	1986-03-27	30	Bayern
160170	1208	2	Shkodran Mustafi 	DF	1992-04-17	24	Valencia
160166	1208	3	Jonas Hector 	DF	1990-05-27	26	Koln
160167	1208	4	Benedikt Howedes 	DF	1988-02-29	28	Schalke
160168	1208	5	Mats Hummels 	DF	1988-12-16	27	Dortmund
160175	1208	6	Sami Khedira 	MF	1987-04-04	29	Juventus
160180	1208	7	Bastian Schweinsteiger 	MF	1984-08-01	31	Man. United
160177	1208	8	Mesut ozil 	MF	1988-10-15	27	Arsenal
160179	1208	9	Andre Schurrle 	MF	1990-11-06	25	Wolfsburg
160184	1208	10	Lukas Podolski 	FD	1985-06-04	31	Galatasaray
160173	1208	11	Julian Draxler 	MF	1993-09-20	22	Wolfsburg
160162	1208	12	Bernd Leno 	GK	1992-03-04	24	Leverkusen
160183	1208	13	Thomas Muller 	FD	1989-09-13	26	Bayern
160172	1208	14	Emre Can 	MF	1994-01-12	22	Liverpool
160181	1208	15	Julian Weigl 	MF	1995-09-08	20	Dortmund
160171	1208	16	Jonathan Tah 	DF	1996-02-11	20	Leverkusen
160165	1208	17	Jerome Boateng 	DF	1988-09-03	27	Bayern
160176	1208	18	Toni Kroos 	MF	1990-01-04	26	Real Madrid
160174	1208	19	Mario Gotze 	MF	1992-06-03	24	Bayern
160178	1208	20	Leroy Sane 	MF	1996-01-11	20	Schalke
160169	1208	21	Joshua Kimmich 	DF	1995-02-08	21	Bayern
160164	1208	22	Marc-Andre ter Stegen 	GK	1992-04-30	24	Barcelona
160182	1208	23	Mario Gomez 	FD	1985-07-10	30	Besiktas
160187	1209	1	Gabor Kiraly 	GK	1976-04-01	40	Haladas
160194	1209	2	Adam Lang 	DF	1993-01-17	23	Videoton
160193	1209	3	Mihaly Korhut 	DF	1988-12-01	27	Debrecen
160192	1209	4	Tamas Kadar 	DF	1990-03-14	26	Lech
160189	1209	5	Attila Fiola 	DF	1990-02-17	26	Puskas Akademia
160196	1209	6	Akos Elek 	MF	1988-07-21	27	Diosgyor
160202	1209	7	Balazs Dzsudzsak 	FD	1986-12-23	29	Bursaspor
160199	1209	8	Adam Nagy 	MF	1995-06-17	21	Ferencvaros
160207	1209	9	Adam Szalai 	FD	1987-12-09	28	Hannover
160203	1209	10	Zoltan Gera 	FD	1979-04-22	37	Ferencvaros
160204	1209	11	Krisztian Nemeth 	FD	1989-01-05	27	Al-Gharafa
160185	1209	12	Denes Dibusz 	GK	1990-11-16	25	Ferencvaros
160201	1209	13	Daniel Bode 	FD	1986-10-24	29	Ferencvaros
160198	1209	14	Gergo Lovrencsics 	MF	1988-09-01	27	Lech
160197	1209	15	Laszlo Kleinheisler 	MF	1994-04-08	22	Bremen
160195	1209	16	adam Pinter 	DF	1988-06-12	28	Ferencvaros
160205	1209	17	Nemanja Nikolic 	FD	1987-12-31	28	Legia
160200	1209	18	Zoltan Stieber 	MF	1988-10-16	27	Nurnberg
160206	1209	19	Tamas Priskin 	FD	1986-09-27	29	Slovan Bratislava
160190	1209	20	Richard Guzmics 	DF	1987-04-16	29	Wisla
160188	1209	21	Barnabas Bese 	DF	1994-05-06	22	MTK
160186	1209	22	Peter Gulacsi 	GK	1990-05-06	26	Leipzig
160191	1209	23	Roland Juhasz 	DF	1983-07-01	32	Videoton
160208	1210	1	Hannes Halldorsson 	GK	1984-04-27	32	Bodo/Glimt
160216	1210	2	Birkir Saevarsson 	DF	1984-11-11	31	Hammarby
160212	1210	3	Haukur Heidar Hauksson 	DF	1991-09-01	24	AIK
160213	1210	4	Hjortur Hermannsson 	DF	1995-02-08	21	Goteborg
160214	1210	5	Sverrir Ingason 	DF	1993-08-05	22	Lokeren
160217	1210	6	Ragnar Sigurdsson 	DF	1986-06-19	29	Krasnodar
160229	1210	7	Johann Gudmundsson 	FD	1990-10-27	25	Charlton
160221	1210	8	Birkir Bjarnason 	MF	1988-05-27	28	Basel
160230	1210	9	Kolbeinn Sigthorsson 	FD	1990-03-14	26	Nantes
160224	1210	10	Gylfi Sigurdsson 	MF	1989-09-08	26	Swansea
160227	1210	11	Alfred Finnbogason 	FD	1989-02-01	27	Augsburg
160210	1210	12	Ogmundur Kristinsson 	GK	1989-06-19	26	Hammarby
160209	1210	13	Ingvar Jonsson 	GK	1989-10-18	26	Sandefjord
160220	1210	14	Kari Arnason 	MF	1982-10-13	33	Malmo
160226	1210	15	Jon Dadi Bodvarsson 	FD	1992-05-25	24	Kaiserslautern
160225	1210	16	Runar Mar Sigurjonsson 	MF	1990-06-18	26	Sundsvall
160222	1210	17	Aron Gunnarsson 	MF	1989-04-22	27	Cardiff
160211	1210	18	Elmar Bjarnason 	DF	1987-03-04	29	AGF
160215	1210	19	Hordur Magnusson 	DF	1993-02-11	23	Cesena
160223	1210	20	Emil Hallfredsson 	MF	1984-06-29	31	Udinese
160219	1210	21	Arnor Ingvi Traustason 	DF	1993-04-30	23	Norrkoping
160228	1210	22	Eidur Gudjohnsen 	FD	1978-09-15	37	Molde
160218	1210	23	Ari Skulason 	DF	1987-05-14	29	OB
160231	1211	1	Gianluigi Buffon 	GK	1978-01-28	38	Juventus
160238	1211	2	Mattia De Sciglio 	DF	1992-10-20	23	Milan
160236	1211	3	Giorgio Chiellini 	DF	1984-08-14	31	Juventus
160237	1211	4	Matteo Darmian 	DF	1989-12-02	26	Man. United
160239	1211	5	Angelo Ogbonna 	DF	1988-05-23	28	West Ham
160241	1211	6	Antonio Candreva 	MF	1987-02-28	29	Lazio
160253	1211	7	Simone Zaza 	FD	1991-06-25	24	Juventus
160243	1211	8	Alessandro Florenzi 	MF	1991-03-11	25	Roma
160252	1211	9	Graziano Pelle	FD	1985-07-15	30	Southampton
160245	1211	10	Thiago Motta 	MF	1982-08-28	33	Paris
160250	1211	11	Ciro Immobile 	FD	1990-02-20	26	Torino
160233	1211	12	Salvatore Sirigu 	GK	1987-01-12	29	Paris
160232	1211	13	Federico Marchetti 	GK	1983-02-07	33	Lazio
160247	1211	14	Stefano Sturaro 	MF	1993-03-09	23	Juventus
160234	1211	15	Andrea Barzagli 	DF	1981-05-08	35	Juventus
160242	1211	16	Daniele De Rossi 	MF	1983-07-24	32	Roma
160248	1211	17	Eder 	FD	1986-11-15	29	Internazionale
160246	1211	18	Marco Parolo 	MF	1985-01-25	31	Lazio
160235	1211	19	Leonardo Bonucci 	DF	1987-05-01	29	Juventus
160251	1211	20	Lorenzo Insigne 	FD	1991-06-04	25	Napoli
160240	1211	21	Federico Bernardeschi 	MF	1994-02-16	22	Fiorentina
160249	1211	22	Stephan El Shaarawy 	FD	1992-10-27	23	Roma
160244	1211	23	Emanuele Giaccherini 	MF	1985-05-05	31	Bologna
160256	1212	1	Michael McGovern 	GK	1984-07-12	31	Hamilton
160264	1212	2	Conor McLaughlin 	DF	1991-07-26	24	Fleetwood
160269	1212	3	Shane Ferguson 	MF	1991-07-12	24	Millwall
160262	1212	4	Gareth McAuley 	DF	1979-12-05	36	West Brom
160259	1212	5	Jonny Evans 	DF	1988-01-03	28	West Brom
160257	1212	6	Chris Baird 	DF	1982-02-25	34	Fulham
160275	1212	7	Niall McGinn 	FD	1987-07-20	28	Aberdeen
160267	1212	8	Steven Davis 	MF	1985-01-01	31	Southampton
160273	1212	9	Will Grigg 	FD	1991-07-03	24	Wigan
160274	1212	10	Kyle Lafferty 	FD	1987-09-16	28	Birmingham
160276	1212	11	Conor Washington 	FD	1992-05-18	24	QPR
160254	1212	12	Roy Carroll	GK	1977-09-30	38	Notts County
160268	1212	13	Corry Evans 	MF	1990-07-30	25	Blackburn
160266	1212	14	Stuart Dallas 	MF	1991-04-19	25	Leeds
160263	1212	15	Luke McCullough 	DF	1994-02-15	22	Doncaster
160271	1212	16	Oliver Norwood 	MF	1991-04-12	25	Reading
160265	1212	17	Paddy McNair 	DF	1995-04-27	21	Man. United
160261	1212	18	Aaron Hughes 	DF	1979-11-08	36	Melbourne City
160272	1212	19	Jamie Ward 	MF	1986-05-12	30	Nottm Forest
160258	1212	20	Craig Cathcart 	DF	1989-02-06	27	Watford
160270	1212	21	Josh Magennis 	MF	1990-08-15	25	Kilmarnock
160260	1212	22	Lee Hodson 	DF	1991-10-02	24	MK Dons
160255	1212	23	Alan Mannus 	GK	1982-05-19	34	St Johnstone
160279	1213	1	Wojciech Szczesny 	GK	1990-04-18	26	Roma
160283	1213	2	Michal Pazdan 	DF	1987-09-21	28	Legia
160282	1213	3	Artur Jedrzejczyk 	DF	1987-11-04	28	Legia
160280	1213	4	Thiago Cionek 	DF	1986-04-21	30	Palermo
160293	1213	5	Krzysztof Maczynski 	MF	1987-05-23	29	Wisla
160289	1213	6	Tomasz Jodlowiec 	MF	1985-09-08	30	Legia
160298	1213	7	Arkadiusz Milik 	FD	1994-02-28	22	Ajax
160292	1213	8	Karol Linetty 	MF	1995-02-02	21	Lech
160297	1213	9	Robert Lewandowski 	FD	1988-08-21	27	Bayern
160291	1213	10	Grzegorz Krychowiak 	MF	1990-01-29	26	Sevilla
160288	1213	11	Kamil Grosicki 	MF	1988-06-08	28	Rennes
160277	1213	12	Artur Boruc 	GK	1980-02-20	36	Bournemouth
160299	1213	13	Mariusz Stepinski 	FD	1995-05-12	21	Ruch
160286	1213	14	Jakub Wawrzyniak 	DF	1983-07-07	32	Lechia
160281	1213	15	Kamil Glik 	DF	1988-02-03	28	Torino
160287	1213	16	Jakub Blaszczykowski 	MF	1985-12-14	30	Fiorentina
160294	1213	17	Slawomir Peszko 	MF	1985-02-19	31	Lechia
160285	1213	18	Bartosz Salamon 	DF	1991-05-01	25	Cagliari
160296	1213	19	Piotr Zielinski 	MF	1994-05-20	22	Empoli
160284	1213	20	Lukasz Piszczek 	DF	1985-06-03	31	Dortmund
160290	1213	21	Bartosz Kapustka 	MF	1996-12-23	19	
160278	1213	22	Lukasz Fabianski 	GK	1985-04-18	31	Swansea
160295	1213	23	Filip Starzynski 	MF	1991-05-27	25	Zaglebie
160302	1214	1	Rui Patricio 	GK	1988-02-15	28	Sporting CP
160303	1214	2	Bruno Alves 	DF	1981-11-27	34	Fenerbahce
160307	1214	3	Pepe 	DF	1983-02-26	33	Real Madrid
160306	1214	4	Jose Fonte 	DF	1983-12-22	32	Southampton
160308	1214	5	Raphael Guerreiro 	DF	1993-12-22	22	Lorient
160309	1214	6	Ricardo Carvalho 	DF	1978-05-18	38	Monaco
160322	1214	7	Cristiano Ronaldo 	FD	1985-02-05	31	Real Madrid
160314	1214	8	Joao Moutinho 	MF	1986-09-08	29	Monaco
160319	1214	9	Eder 	FD	1987-12-22	28	LOSC
160313	1214	10	Joao Mario 	MF	1993-01-19	23	Sporting CP
160317	1214	11	Vieirinha 	MF	1986-01-24	30	Wolfsburg
160301	1214	12	Anthony Lopes 	GK	1990-10-01	25	Lyon
160312	1214	13	Danilo 	MF	1991-09-09	24	Porto
160318	1214	14	William Carvalho 	MF	1992-04-07	24	Sporting CP
160311	1214	15	Andre Gomes 	MF	1993-07-30	22	Valencia
160316	1214	16	Renato Sanches 	MF	1997-08-18	18	Benfica
160320	1214	17	Nani 	FD	1986-11-17	29	Fenerbahce
160315	1214	18	Rafa Silva 	MF	1993-05-17	23	Braga
160305	1214	19	Eliseu 	DF	1983-10-01	32	Benfica
160321	1214	20	Ricardo Quaresma 	FD	1983-09-26	32	Besiktas
160304	1214	21	Cedric 	DF	1991-08-31	24	Southampton
160300	1214	22	Eduardo 	GK	1982-09-19	33	Dinamo Zagreb
160310	1214	23	Adrien Silva 	MF	1989-03-15	27	Sporting CP
160325	1215	1	Keiren Westwood 	GK	1984-10-23	31	Sheff. Wednesday
160328	1215	2	Seamus Coleman 	DF	1988-10-11	27	Everton
160327	1215	3	Ciaran Clark 	DF	1989-09-26	26	Aston Villa
160331	1215	4	John OShea 	DF	1981-04-30	35	Sunderland
160330	1215	5	Richard Keogh 	DF	1986-08-11	29	Derby
160341	1215	6	Glenn Whelan 	MF	1984-01-13	32	Stoke
160338	1215	7	Aiden McGeady 	MF	1986-04-04	30	Sheff. Wednesday
160336	1215	8	James McCarthy 	MF	1990-11-12	25	Everton
160343	1215	9	Shane Long 	FD	1987-01-22	29	Southampton
160342	1215	10	Robbie Keane 	FD	1980-07-08	35	LA Galaxy
160337	1215	11	James McClean 	MF	1989-04-22	27	West Brom
160329	1215	12	Shane Duffy 	DF	1992-01-01	24	Blackburn
160334	1215	13	Jeff Hendrick 	MF	1992-01-31	24	Derby
160345	1215	14	Jon Walters 	FD	1983-09-20	32	Stoke
160326	1215	15	Cyrus Christie 	DF	1992-09-30	23	Derby
160323	1215	16	Shay Given 	GK	1976-04-20	40	Stoke
160332	1215	17	Stephen Ward 	DF	1985-08-20	30	Burnley
160339	1215	18	David Meyler 	MF	1989-05-29	27	Hull
160333	1215	19	Robbie Brady 	MF	1992-01-14	24	Norwich
160335	1215	20	Wes Hoolahan 	MF	1982-05-20	34	Norwich
160344	1215	21	Daryl Murphy 	FD	1983-03-15	33	Ipswich
160340	1215	22	Stephen Quinn 	MF	1986-04-01	30	Reading
160324	1215	23	Darren Randolph 	GK	1987-05-12	29	West Ham
160347	1216	1	Costel Pantilimon 	GK	1987-02-01	29	Watford
160353	1216	2	Alexandru Matel 	DF	1989-10-17	26	Dinamo Zagreb
160355	1216	3	Razvan Rat 	DF	1981-05-26	35	Rayo Vallecano
160354	1216	4	Cosmin Moti 	DF	1984-12-03	31	Ludogorets
160358	1216	5	Ovidiu Hoban 	MF	1982-12-27	33	H. Beer-Sheva
160349	1216	6	Vlad Chiriches 	DF	1989-11-14	26	Napoli
160357	1216	7	Alexandru Chipciu 	MF	1989-05-18	27	Steaua
160359	1216	8	Mihai Pintilii 	MF	1984-11-09	31	Steaua
160365	1216	9	Denis Alibec 	FD	1991-01-05	25	Astra
160363	1216	10	Nicolae Stanciu 	MF	1993-05-07	23	Steaua
160364	1216	11	Gabriel Torje 	MF	1989-11-22	26	Osmanlispor
160348	1216	12	Ciprian Tatarusanu 	GK	1986-02-09	30	Fiorentina
160367	1216	13	Claudiu Keeru 	FD	1986-12-02	29	Ludogorets
160366	1216	14	Florin Andone 	FD	1993-04-11	23	Cordoba
160351	1216	15	Valerica Gaman 	DF	1989-02-25	27	Astra
160350	1216	16	Steliano Filip 	DF	1994-05-15	22	Dinamo Bucuresti
160362	1216	17	Lucian Sanmartean 	MF	1980-03-13	36	Al-Ittihad
160361	1216	18	Andrei Prepelita 	MF	1985-12-08	30	Ludogorets
160368	1216	19	Bogdan Stancu 	FD	1987-06-28	28	Genclerbirligi
160360	1216	20	Adrian Popa 	MF	1988-07-24	27	Steaua
160352	1216	21	Dragos Grigore 	DF	1986-09-07	29	Al-Sailiya
160356	1216	22	Cristian Sapunaru 	DF	1984-04-05	32	Pandurii
160346	1216	23	Silviu Lung 	GK	1989-06-04	27	Astra
160369	1217	1	Igor Akinfeev 	GK	1986-04-08	30	CSKA Moskva
160378	1217	2	Roman Shishkin 	DF	1987-01-27	29	Lokomotiv Moskva
160379	1217	3	Igor Smolnikov 	DF	1988-08-08	27	Zenit
160374	1217	4	Sergei Ignashevich 	DF	1979-07-14	36	CSKA Moskva
160376	1217	5	Roman Neustadter 	DF	1988-02-18	28	Schalke
160372	1217	6	Aleksei Berezutski 	DF	1982-06-20	33	CSKA Moskva
160388	1217	7	Artur Yusupov 	MF	1989-09-01	26	Zenit
160380	1217	8	Denis Glushakov 	MF	1987-01-27	29	Spartak Moskva
160390	1217	9	Aleksandr Kokorin 	FD	1991-03-19	25	Zenit
160391	1217	10	Fedor Smolov 	FD	1990-02-09	26	Krasnodar
160383	1217	11	Pavel Mamaev 	MF	1988-09-17	27	Krasnodar
160371	1217	12	Yuri Lodygin 	GK	1990-05-26	26	Zenit
160381	1217	13	Aleksandr Golovin 	MF	1996-05-30	20	CSKA Moskva
160373	1217	14	Vasili Berezutski 	DF	1982-06-20	33	CSKA Moskva
160386	1217	15	Roman Shirokov 	MF	1981-07-06	34	CSKA Moskva
160370	1217	16	Guilherme 	GK	1985-12-12	30	Lokomotiv Moskva
160385	1217	17	Oleg Shatov 	MF	1990-07-29	25	Zenit
160382	1217	18	Oleg Ivanov 	MF	1986-08-04	29	Terek
160384	1217	19	Aleksandr Samedov 	MF	1984-07-19	31	Lokomotiv Moskva
160387	1217	20	Dmitri Torbinski 	MF	1984-04-28	32	Krasnodar
160377	1217	21	Georgi Schennikov 	DF	1991-04-27	25	CSKA Moskva
160389	1217	22	Artem Dzyuba 	FD	1988-08-22	27	Zenit
160375	1217	23	Dmitri Kombarov 	DF	1987-01-22	29	Spartak Moskva
160393	1218	1	Jan Mucha 	GK	1982-12-05	33	Slovan Bratislava
160398	1218	2	Peter Pekarik 	DF	1986-10-30	29	Hertha
160401	1218	3	Martin Skrtel 	DF	1984-12-15	31	Liverpool
160395	1218	4	Jan Durica 	DF	1981-12-10	34	Lokomotiv Moskva
160396	1218	5	Norbert Gyomber 	DF	1992-07-03	23	Roma
160404	1218	6	Jan Gregus	MF	1991-01-29	25	Jablonec
160411	1218	7	Vladimir Weiss 	MF	1989-11-30	26	Al-Gharafa
160403	1218	8	Ondrej Duda 	MF	1994-12-05	21	Legia
160414	1218	9	Stanislav Sestak 	FD	1982-12-16	33	Ferencvaros
160410	1218	10	Miroslav Stoch 	MF	1989-10-19	26	Bursaspor
160413	1218	11	Adam Nemec 	FD	1985-09-02	30	Willem II
160394	1218	12	Jan Novota 	GK	1983-11-29	32	Rapid Wien
160406	1218	13	Patrik HroSovsky 	MF	1992-04-22	24	Plzen
160400	1218	14	Milan Skriniar 	DF	1995-02-11	21	Sampdoria
160397	1218	15	TomasHubocan 	DF	1985-09-17	30	Dinamo Moskva
160399	1218	16	Kornel Salata 	DF	1985-01-24	31	Slovan Bratislava
160405	1218	17	Marek Hamsik 	MF	1987-07-27	28	Napoli
160402	1218	18	Dusan Svento 	DF	1985-08-01	30	Koln
160407	1218	19	Juraj Kucka 	MF	1987-02-26	29	Milan
160408	1218	20	Robert Mak 	MF	1991-03-08	25	PAOK
160412	1218	21	Michal Duris	FD	1988-06-01	28	Plzen
160409	1218	22	Viktor Pecovsky 	MF	1983-05-24	33	zilina
160392	1218	23	MatusKozacik 	GK	1983-12-27	32	Plzen
160415	1219	1	Lker Casillas 	GK	1981-05-20	35	Porto
160418	1219	2	Cesar Azpilicueta 	DF	1989-08-28	26	Chelsea
160423	1219	3	Gerard Pique 	DF	1987-02-02	29	Barcelona
160419	1219	4	Marc Bartra 	DF	1991-01-15	25	Barcelona
160427	1219	5	Sergio Busquets 	MF	1988-07-16	27	Barcelona
160429	1219	6	Andres Iniesta 	MF	1984-05-11	32	Barcelona
160435	1219	7	Alvaro Morata 	FD	1992-10-23	23	Juventus
160430	1219	8	Koke 	MF	1992-01-08	24	Atletico
160434	1219	9	Lucas Vazquez 	FD	1991-07-01	24	Real Madrid
160428	1219	10	Cesc Fabregas 	MF	1987-05-04	29	Chelsea
160437	1219	11	Pedro Rodriguez 	FD	1987-07-28	28	Chelsea
160420	1219	12	Hector Bellerin 	DF	1995-03-19	21	Arsenal
160416	1219	13	David de Gea 	GK	1990-11-07	25	Man. United
160432	1219	14	Thiago Alcantara 	MF	1991-04-11	25	Bayern
160424	1219	15	Sergio Ramos 	DF	1986-03-30	30	Real Madrid
160422	1219	16	Juanfran 	DF	1985-01-09	31	Atletico
160425	1219	17	Mikel San Jose 	DF	1989-05-30	27	Athletic
160421	1219	18	Jordi Alba 	DF	1989-03-21	27	Barcelona
160426	1219	19	Bruno Soriano 	MF	1984-06-12	32	Villarreal
160433	1219	20	Aritz Aduriz 	FD	1981-02-11	35	Athletic
160431	1219	21	David Silva 	MF	1986-01-08	30	Man. City
160436	1219	22	Nolito 	FD	1986-10-15	29	Celta
160417	1219	23	Sergio Rico 	GK	1993-09-01	22	Sevilla
160439	1220	1	Andreas Isaksson 	GK	1981-10-03	34	Kasimpasa
160446	1220	2	Mikael Lustig 	DF	1986-12-13	29	Celtic
160444	1220	3	Erik Johansson 	DF	1988-12-30	27	Kobenhavn
160442	1220	4	Andreas Granqvist 	DF	1985-04-16	31	Krasnodar
160447	1220	5	Martin Olsson 	DF	1988-05-17	28	Norwich
160451	1220	6	Emil Forsberg 	MF	1991-10-23	24	Leipzig
160454	1220	7	Sebastian Larsson 	MF	1985-06-06	31	Sunderland
160449	1220	8	Albin Ekdal 	MF	1989-07-28	26	Hamburg
160453	1220	9	Kim Kallstrom 	MF	1982-08-24	33	Grasshoppers
160459	1220	10	Zlatan Ibrahimovic 	FD	1981-10-03	34	Paris
160457	1220	11	Marcus Berg 	FD	1986-08-17	29	Panathinaikos
160440	1220	12	Robin Olsen 	GK	1990-01-08	26	Kobenhavn
160443	1220	13	Pontus Jansson 	DF	1991-02-13	25	Torino
160445	1220	14	Victor Lindelof 	DF	1994-07-17	21	Benfica
160452	1220	15	Oscar Hiljemark 	MF	1992-06-28	23	Palermo
160456	1220	16	Pontus Wernbloom 	MF	1986-06-25	29	CSKA Moskva
160441	1220	17	Ludwig Augustinsson 	DF	1994-04-21	22	Kobenhavn
160455	1220	18	Oscar Lewicki 	MF	1992-07-14	23	Malmo
160460	1220	19	Emir Kujovic 	FD	1988-06-22	27	Norrkoping
160458	1220	20	John Guidetti 	FD	1992-04-15	24	Celta
160448	1220	21	Jimmy Durmaz 	MF	1989-03-22	27	Olympiacos
160450	1220	22	Erkan Zengin 	MF	1985-08-05	30	Trabzonspor
160438	1220	23	Patrik Carlgren 	GK	1992-01-08	24	AIK
160463	1221	1	Yann Sommer 	GK	1988-12-17	27	Monchengladbach
160467	1221	2	Stephan Lichtsteiner 	DF	1984-01-16	32	Juventus
160468	1221	3	Francois Moubandje 	DF	1990-06-21	25	Toulouse
160465	1221	4	Nico Elvedi 	DF	1996-09-30	19	Monchengladbach
160471	1221	5	Steve von Bergen 	DF	1983-06-10	33	Young Boys
160466	1221	6	Michael Lang 	DF	1991-02-08	25	Basel
160480	1221	7	Breel Embolo 	FD	1997-02-14	19	Basel
160475	1221	8	Fabian Frei 	MF	1989-01-08	27	Mainz
160482	1221	9	Haris Seferovic 	FD	1992-02-22	24	Frankfurt
160477	1221	10	Granit Xhaka 	MF	1992-09-27	23	Monchengladbach
160472	1221	11	Valon Behrami 	MF	1985-04-19	31	Watford
160462	1221	12	Marwin Hitz 	GK	1987-09-18	28	Augsburg
160469	1221	13	Ricardo Rodriguez 	DF	1992-08-25	23	Wolfsburg
160478	1221	14	Denis Zakaria 	MF	1996-11-20	19	Young Boys
160473	1221	15	Blerim Dzemaili 	MF	1986-04-12	30	Genoa
160474	1221	16	Gelson Fernandes 	MF	1986-09-02	29	Rennes
160483	1221	17	Shani Tarashaj 	FD	1995-02-07	21	Grasshoppers
160481	1221	18	Admir Mehmedi 	FD	1991-03-16	25	Leverkusen
160479	1221	19	Eren Derdiyok 	FD	1988-06-12	28	Kasimpasa
160464	1221	20	Johan Djourou 	DF	1987-01-18	29	Hamburg
160461	1221	21	Roman Burki 	GK	1990-11-14	25	Dortmund
160470	1221	22	Fabian Schar 	DF	1991-12-20	24	Hoffenheim
160476	1221	23	Xherdan Shaqiri 	MF	1991-10-10	24	Stoke
160486	1222	1	Volkan Babacan 	GK	1988-08-11	27	Istanbul Basaksehir
160492	1222	2	Semih Kaya 	DF	1991-02-24	25	Galatasaray
160490	1222	3	Hakan Balta 	DF	1983-03-23	33	Galatasaray
160487	1222	4	Ahmet Calik 	DF	1994-02-26	22	Genclerbirligi
160497	1222	5	Nuri Sahin 	MF	1988-09-05	27	Dortmund
160495	1222	6	Hakan Calhanoglu 	MF	1994-02-08	22	Leverkusen
160489	1222	7	Gokhan Gonul 	DF	1985-01-04	31	Fenerbahce
160501	1222	8	Selcuk Inan 	MF	1985-02-10	31	Galatasaray
160505	1222	9	Cenk Tosun 	FD	1991-06-07	25	Besiktas
160494	1222	10	Arda Turan 	MF	1987-01-30	29	Barcelona
160499	1222	11	Olcay Sahan 	MF	1987-05-26	29	Besiktas
160485	1222	12	Onur Kivrak 	GK	1988-01-01	28	Trabzonspor
160491	1222	13	Ismail Koybasi 	DF	1989-07-10	26	Besiktas
160498	1222	14	Oguzhan Ozyakup 	MF	1992-09-23	23	Besiktas
160496	1222	15	Mehmet Topal 	MF	1986-03-03	30	Fenerbahce
160500	1222	16	Ozan Tufan 	MF	1995-03-23	21	Fenerbahce
160504	1222	17	Burak Yilmaz 	FD	1985-07-15	30	Beijing Guoan
160488	1222	18	Caner Erkin 	DF	1988-10-04	27	Fenerbahce
160503	1222	19	Yunus Malli 	MF	1992-02-24	24	Mainz
160502	1222	20	Volkan Sen 	MF	1987-07-07	28	Fenerbahce
160506	1222	21	Emre Mor 	FD	1997-07-24	18	Nordsjælland
160493	1222	22	Sener Ozbayrakli 	DF	1990-01-23	26	Fenerbahce
160484	1222	23	Harun Tekin 	GK	1989-06-17	27	Bursaspor
160507	1223	1	Denys Boyko 	GK	1988-01-29	28	Besiktas
160510	1223	2	Bohdan Butko 	DF	1991-01-13	25	Amkar
160512	1223	3	Yevhen Khacheridi 	DF	1987-07-28	28	Dynamo Kyiv
160524	1223	4	Anatoliy Tymoshchuk 	MF	1979-03-30	37	Kairat
160513	1223	5	Olexandr Kucher 	DF	1982-10-22	33	Shakhtar Donetsk
160522	1223	6	Taras Stepanenko 	MF	1989-08-08	26	Shakhtar Donetsk
160525	1223	7	Andriy Yarmolenko 	MF	1989-10-23	26	Dynamo Kyiv
160529	1223	8	Roman Zozulya 	FD	1989-11-17	26	Dnipro
160519	1223	9	Viktor Kovalenko 	MF	1996-02-14	20	Shakhtar Donetsk
160518	1223	10	Yevhen Konoplyanka 	MF	1989-09-29	26	Sevilla
160528	1223	11	Yevhen Seleznyov 	FD	1985-07-20	30	Shakhtar Donetsk
160508	1223	12	Andriy Pyatov 	GK	1984-06-28	31	Shakhtar Donetsk
160515	1223	13	Vyacheslav Shevchuk 	DF	1979-05-13	37	Shakhtar Donetsk
160520	1223	14	Ruslan Rotan 	MF	1981-10-29	34	Dnipro
160527	1223	15	Pylyp Budkivskiy 	FD	1992-03-10	24	Zorya
160523	1223	16	Serhiy Sydorchuk 	MF	1991-05-02	25	Dynamo Kyiv
160511	1223	17	Artem Fedetskiy 	DF	1985-04-26	31	Dnipro
160521	1223	18	Serhiy Rybalka 	MF	1990-04-01	26	Dynamo Kyiv
160516	1223	19	Denys Garmash 	MF	1990-04-19	26	Dynamo Kyiv
160514	1223	20	Yaroslav Rakitskiy 	DF	1989-08-03	26	Shakhtar Donetsk
160526	1223	21	Olexandr Zinchenko 	MF	1996-12-15	19	Ufa
160517	1223	22	Olexandr Karavaev 	MF	1992-06-02	24	Zorya
160509	1223	23	Mykyta Shevchenko 	GK	1993-01-26	23	Zorya
160531	1224	1	Wayne Hennessey 	GK	1987-01-24	29	Crystal Palace
160536	1224	2	Chris Gunter 	DF	1989-07-21	26	Reading
160538	1224	3	Neil Taylor 	DF	1989-02-07	27	Swansea
160535	1224	4	Ben Davies 	DF	1993-04-24	23	Tottenham
160533	1224	5	James Chester 	DF	1989-01-23	27	West Brom
160539	1224	6	Ashley Williams 	DF	1984-08-23	31	Swansea
160540	1224	7	Joe Allen 	MF	1990-03-14	26	Liverpool
160542	1224	8	Andy King 	MF	1988-10-29	27	Leicester
160550	1224	9	Hal Robson-Kanu 	FD	1989-05-21	27	Reading
160544	1224	10	Aaron Ramsey 	MF	1990-12-26	25	Arsenal
160547	1224	11	Gareth Bale 	FD	1989-07-16	26	Real Madrid
160530	1224	12	Owain Fon Williams 	GK	1987-03-17	29	Inverness
160552	1224	13	George Williams 	FD	1995-09-07	20	Fulham
160541	1224	14	David Edwards 	MF	1986-02-03	30	Wolves
160537	1224	15	Jazz Richards 	DF	1991-04-12	25	Fulham
160543	1224	16	Joe Ledley 	MF	1987-01-23	29	Crystal Palace
160549	1224	17	David Cotterill 	FD	1987-12-04	28	Birmingham
160551	1224	18	Sam Vokes 	FD	1989-10-21	26	Burnley
160534	1224	19	James Collins 	DF	1983-08-23	32	West Ham
160546	1224	20	Jonathan Williams 	MF	1993-10-09	22	Crystal Palace
160532	1224	21	Danny Ward 	GK	1993-06-22	22	Liverpool
160545	1224	22	David Vaughan 	MF	1983-02-18	33	Nottm Forest
160548	1224	23	Simon Church 	FD	1988-12-10	27	MK Dons
\.


--
-- Data for Name: playing_position; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playing_position (position_id, position_desc) FROM stdin;
GK	Goalkeepers
DF	Defenders
MF	Midfielders
FD	Defenders
\.


--
-- Data for Name: prescribes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.prescribes (physician, patient, medication, date, appointment, dose) FROM stdin;
1	100000001	1	2008-04-24 10:47:00	13216584	5
9	100000004	2	2008-04-27 10:53:00	86213939	10
9	100000004	2	2008-04-30 16:53:00	\N	5
\.


--
-- Data for Name: procedure; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.procedure (code, name, cost) FROM stdin;
1	Reverse Rhinopodoplasty	1500
2	Obtuse Pyloric Recombobulation	3750
3	Folded Demiophtalmectomy	4500
4	Complete Walletectomy	10000
5	Obfuscated Dermogastrotomy	4899
6	Reversible Pancreomyoplasty	5600
7	Follicular Demiectomy	25
\.


--
-- Data for Name: rating; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rating (mov_id, rev_id, rev_stars, num_o_ratings) FROM stdin;
901	9001	8.40	263575
902	9002	7.90	20207
903	9003	8.30	202778
906	9005	8.20	484746
924	9006	7.30	\N
908	9007	8.60	779489
909	9008	\N	227235
910	9009	3.00	195961
911	9010	8.10	203875
912	9011	8.40	\N
914	9013	7.00	862618
915	9001	7.70	830095
916	9014	4.00	642132
925	9015	7.70	81328
918	9016	\N	580301
920	9017	8.10	609451
921	9018	8.00	667758
922	9019	8.40	511613
923	9020	6.70	13091
\.


--
-- Data for Name: referee_mast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.referee_mast (referee_id, referee_name, country_id) FROM stdin;
70001	Damir Skomina	1225
70002	Martin Atkinson	1206
70003	Felix Brych	1208
70004	Cuneyt Cakir	1222
70005	Mark Clattenburg	1206
70006	Jonas Eriksson	1220
70007	Viktor Kassai	1209
70008	Bjorn Kuipers	1226
70009	Szymon Marciniak	1213
70010	Milorad Mazic	1227
70011	Nicola Rizzoli	1211
70012	Carlos Velasco Carballo	1219
70013	William Collum	1228
70014	Ovidiu Hategan	1216
70015	Sergei Karasev	1217
70016	Pavel Kralovec	1205
70017	Svein Oddvar Moen	1229
70018	Clement Turpin	1207
\.


--
-- Data for Name: regions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.regions (region_id, region_name) FROM stdin;
1	Europe                   
2	Americas                 
3	Asia                     
4	Middle East and Africa   
\.


--
-- Data for Name: related; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.related (city) FROM stdin;
New York
\.


--
-- Data for Name: reviewer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reviewer (rev_id, rev_name) FROM stdin;
9001	Righty Sock                   
9002	Jack Malvern                  
9003	Flagrant Baronessa            
9004	Alec Shaw                     
9005	\N
9006	Victor Woeltjen               
9007	Simon Wright                  
9008	Neal Wruck                    
9009	Paul Monks                    
9010	Mike Salvati                  
9011	\N
9012	Wesley S. Walker              
9013	Sasha Goldshtein              
9014	Josh Cates                    
9015	Krug Stillo                   
9016	Scott LeBrun                  
9017	Hannah Steele                 
9018	Vincent Cadena                
9019	Brandt Sponseller             
9020	Richard Adams                 
\.


--
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.room (roomnumber, roomtype, blockfloor, blockcode, unavailable) FROM stdin;
101	Single	1	1	f
102	Single	1	1	f
103	Single	1	1	f
111	Single	1	2	f
112	Single	1	2	t
113	Single	1	2	f
121	Single	1	3	f
122	Single	1	3	f
123	Single	1	3	f
201	Single	2	1	t
202	Single	2	1	f
203	Single	2	1	f
211	Single	2	2	f
212	Single	2	2	f
213	Single	2	2	t
221	Single	2	3	f
222	Single	2	3	f
223	Single	2	3	f
301	Single	3	1	f
302	Single	3	1	t
303	Single	3	1	f
311	Single	3	2	f
312	Single	3	2	f
313	Single	3	2	f
321	Single	3	3	t
322	Single	3	3	f
323	Single	3	3	f
401	Single	4	1	f
402	Single	4	1	t
403	Single	4	1	f
411	Single	4	2	f
412	Single	4	2	f
413	Single	4	2	f
421	Single	4	3	t
422	Single	4	3	f
423	Single	4	3	f
\.


--
-- Data for Name: salesman; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.salesman (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5007	Paul Adam	Rome	0.13
5003	Lauson Hen	San Jose	0.12
\.


--
-- Data for Name: salesman_do1304; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.salesman_do1304 (salesman_id, name, city, commission) FROM stdin;
\.


--
-- Data for Name: sample_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sample_table (salesman_id, name, city, commission) FROM stdin;
\.


--
-- Data for Name: scores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scores (id, score) FROM stdin;
1	100
\.


--
-- Data for Name: soccer_city; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.soccer_city (city_id, city, country_id) FROM stdin;
10001	Paris	1207
10002	Saint-Denis	1207
10003	Bordeaux	1207
10004	Lens	1207
10005	Lille	1207
10006	Lyon	1207
10007	Marseille	1207
10008	Nice	1207
10009	Saint-Etienne	1207
10010	Toulouse	1207
\.


--
-- Data for Name: soccer_country; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.soccer_country (country_id, country_abbr, country_name) FROM stdin;
1201	ALB	Albania
1202	AUT	Austria
1203	BEL	Belgium
1204	CRO	Croatia
1205	CZE	Czech Republic
1206	ENG	England
1207	FRA	France
1208	GER	Germany
1209	HUN	Hungary
1210	ISL	Iceland
1211	ITA	Italy
1212	NIR	Northern Ireland
1213	POL	Poland
1214	POR	Portugal
1215	IRL	Republic of Ireland
1216	ROU	Romania
1217	RUS	Russia
1218	SVK	Slovakia
1219	ESP	Spain
1220	SWE	Sweden
1221	SUI	Switzerland
1222	TUR	Turkey
1223	UKR	Ukraine
1224	WAL	Wales
1225	SLO	Slovenia
1226	NED	Netherlands
1227	SRB	Serbia
1228	SCO	Scotland
1229	NOR	Norway
\.


--
-- Data for Name: soccer_team; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.soccer_team (team_id, team_group, match_played, won, draw, lost, goal_for, goal_agnst, goal_diff, points, group_position) FROM stdin;
1201	A	3	1	0	2	1	3	-2	3	3
1202	F	3	0	1	2	1	4	-3	1	4
1203	E	3	2	0	1	4	2	2	6	2
1204	D	3	2	1	0	5	3	2	7	1
1205	D	3	0	1	2	2	5	-3	1	4
1206	B	3	1	2	0	3	2	1	5	2
1207	A	3	2	1	0	4	1	3	7	1
1208	C	3	2	1	0	3	0	3	7	1
1209	F	3	1	2	0	6	4	2	5	1
1210	F	3	1	2	0	4	3	1	5	2
1211	E	3	2	0	1	3	1	2	6	1
1212	C	3	1	0	2	2	2	0	3	3
1213	C	3	2	1	0	2	0	2	7	2
1214	F	3	0	3	0	4	4	0	3	3
1215	E	3	1	1	1	2	4	-2	4	3
1216	A	3	0	1	2	2	4	-2	1	4
1217	B	3	0	1	2	2	6	-4	1	4
1218	B	3	1	1	1	3	3	0	4	3
1219	D	3	2	0	1	5	2	3	6	2
1220	E	3	0	1	2	1	3	-2	1	4
1221	A	3	1	2	0	2	1	1	5	2
1222	D	3	1	0	2	2	4	-2	3	3
1223	C	3	0	0	3	0	5	-5	0	4
1224	B	3	2	0	1	6	3	3	6	1
\.


--
-- Data for Name: soccer_venue; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.soccer_venue (venue_id, venue_name, city_id, aud_capacity) FROM stdin;
20001	Stade de Bordeaux	10003	42115
20002	Stade Bollaert-Delelis	10004	38223
20003	Stade Pierre Mauroy	10005	49822
20004	Stade de Lyon	10006	58585
20005	Stade VElodrome	10007	64354
20006	Stade de Nice	10008	35624
20007	Parc des Princes	10001	47294
20008	Stade de France	10002	80100
20009	Stade Geoffroy Guichard	10009	42000
20010	Stadium de Toulouse	10010	33150
\.


--
-- Data for Name: statements; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.statements (name) FROM stdin;
This is SQL Exercise, Practice and Solution
\.


--
-- Data for Name: stay; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stay (stayid, patient, room, start_time, end_time) FROM stdin;
3215	100000001	111	2008-05-01 00:00:00	2008-05-04 00:00:00
3216	100000003	123	2008-05-03 00:00:00	2008-05-14 00:00:00
3217	100000004	112	2008-05-02 00:00:00	2008-05-03 00:00:00
\.


--
-- Data for Name: string; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.string (text) FROM stdin;
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student (roll, name) FROM stdin;
\.


--
-- Data for Name: student1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student1 (roll, name) FROM stdin;
\.


--
-- Data for Name: sybba; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sybba (ord_num, ord_amount, ord_date, cust_code, agent_code) FROM stdin;
\.


--
-- Data for Name: table1; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.table1 ("Customer Name", city, "Salesman", commission) FROM stdin;
Nick Rimando	New York	James Hoog	0.15
Brad Davis	New York	James Hoog	0.15
Graham Zusi	California	Nail Knite	0.13
Julian Green	London	Nail Knite	0.13
Fabian Johnson	Paris	Mc Lyon	0.14
Geoff Cameron	Berlin	Lauson Hen	0.12
Jozy Altidor	Moscow	Paul Adam	0.13
Brad Guzan	London	Pit Alex	0.11
\.


--
-- Data for Name: team_coaches; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team_coaches (team_id, coach_id) FROM stdin;
1201	5550
1202	5551
1203	5552
1204	5553
1205	5554
1206	5555
1207	5556
1208	5557
1209	5558
1210	5559
1210	5560
1211	5561
1212	5562
1213	5563
1214	5564
1215	5565
1216	5566
1217	5567
1218	5568
1219	5569
1220	5570
1221	5571
1222	5572
1223	5573
1224	5574
\.


--
-- Data for Name: temp; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.temp (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3007	Brad Davis	New York	200	5001
3003	Jozy Altidor	Moncow	200	5007
3005	Graham Zusi	California	200	5002
3008	Julian Green	London	300	5002
3004	Fabian Johnson	Paris	300	5006
3009	Geoff Cameron	Berlin	100	5003
3001	Brad Guzan	London	\N	5005
\.


--
-- Data for Name: tempa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tempa (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3005	Graham Zusi	California	200	5002
3001	Brad Guzan	London	100	5005
3004	Fabian Johns	Paris	300	5006
3007	Brad Davis	New York	200	5001
3009	Geoff Camero	Berlin	100	5003
3008	Julian Green	London	300	5002
3003	Jozy Altidor	Moncow	200	5007
\.


--
-- Data for Name: tempcustomer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tempcustomer (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3005	Graham Zusi	California	200	5002
3001	Brad Guzan	London	100	5005
3004	Fabian Johns	Paris	300	5006
3007	Brad Davis	New York	200	5001
3009	Geoff Camero	Berlin	100	5003
3008	Julian Green	London	300	5002
3003	Jozy Altidor	Moncow	200	5007
\.


--
-- Data for Name: temphi; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.temphi (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5003	Lauson Hen	San Jose	0.12
5007	Paul Adam	Rome	0.13
\.


--
-- Data for Name: tempp; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tempp (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3007	Brad Davis	New York	200	5001
3003	Jozy Altidor	Moncow	200	5007
3005	Graham Zusi	California	200	5002
3008	Julian Green	London	300	5002
3004	Fabian Johnson	Paris	300	5006
3009	Geoff Cameron	Berlin	100	5003
3001	Brad Guzan	London	\N	5005
\.


--
-- Data for Name: tempp11; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tempp11 (customer_id, cust_name, city, grade, salesman_id) FROM stdin;
3002	Nick Rimando	New York	100	5001
3007	Brad Davis	New York	200	5001
3003	Jozy Altidor	Moncow	200	5007
3005	Graham Zusi	California	200	5002
3008	Julian Green	London	300	5002
3004	Fabian Johnson	Paris	300	5006
3009	Geoff Cameron	Berlin	100	5003
3001	Brad Guzan	London	\N	5005
\.


--
-- Data for Name: tempsalesman; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tempsalesman (salesman_id, name, city, commission) FROM stdin;
5001	James Hoog	New York	0.15
5002	Nail Knite	Paris	0.13
5005	Pit Alex	London	0.11
5006	Mc Lyon	Paris	0.14
5003	Lauson Hen	San Jose	0.12
5007	Paul Adam	Rome	0.13
\.


--
-- Data for Name: test; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test (x) FROM stdin;
1
2
3
\.


--
-- Data for Name: teste; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teste (salesman_id, count) FROM stdin;
5002	2
5001	2
5003	1
5005	1
5007	1
5006	1
\.


--
-- Data for Name: testtable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.testtable (col1) FROM stdin;
A001/DJ-402\\44_/100/2015
A001_\\DJ-402\\44_/100/2015
A001_DJ-402-2014-2015
A002_DJ-401-2014-2015
A001/DJ_401
A001/DJ_402\\44
A001/DJ_402\\44\\2015
A001/DJ-402%45\\2015/200
A001/DJ_402\\45\\2015%100
A001/DJ_402%45\\2015/300
A001/DJ-402\\44
\.


--
-- Data for Name: trained_in; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trained_in (physician, treatment, certificationdate, certificationexpires) FROM stdin;
3	1	2008-01-01	2008-12-31
3	2	2008-01-01	2008-12-31
3	5	2008-01-01	2008-12-31
3	6	2008-01-01	2008-12-31
3	7	2008-01-01	2008-12-31
6	2	2008-01-01	2008-12-31
6	5	2007-01-01	2007-12-31
6	6	2008-01-01	2008-12-31
7	1	2008-01-01	2008-12-31
7	2	2008-01-01	2008-12-31
7	3	2008-01-01	2008-12-31
7	4	2008-01-01	2008-12-31
7	5	2008-01-01	2008-12-31
7	6	2008-01-01	2008-12-31
7	7	2008-01-01	2008-12-31
\.


--
-- Data for Name: trenta; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trenta (numeri) FROM stdin;
\.


--
-- Data for Name: tt; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tt (name) FROM stdin;
\.


--
-- Data for Name: undergoes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.undergoes (patient, procedure, stay, date, physician, assistingnurse) FROM stdin;
100000001	6	3215	2008-05-02 00:00:00	3	101
100000001	2	3215	2008-05-03 00:00:00	7	101
100000004	1	3217	2008-05-07 00:00:00	3	102
100000004	5	3217	2008-05-09 00:00:00	6	\N
100000001	7	3217	2008-05-10 00:00:00	7	101
100000004	4	3217	2008-05-13 00:00:00	3	103
\.


--
-- Data for Name: vowl; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vowl (cust_name, "substring") FROM stdin;
Nick Rimando	o
Graham Zusi	i
Brad Guzan	n
Fabian Johns	s
Brad Davis	s
Geoff Camero	o
Julian Green	n
Jozy Altidor	r
\.


--
-- Data for Name: zebras; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zebras (id, score, date) FROM stdin;
1	100	2015-12-15
3	230	2015-12-15
\.


--
-- Data for Name: zz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zz (customer_id, avg) FROM stdin;
3007	2400.6000000000000000
3008	250.4500000000000000
3002	2956.9533333333333333
3001	270.6500000000000000
3009	1295.4500000000000000
3004	1983.4300000000000000
3003	75.2900000000000000
3005	549.5000000000000000
\.


--
-- Name: actor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor
    ADD CONSTRAINT actor_pkey PRIMARY KEY (act_id);


--
-- Name: affiliated_with_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.affiliated_with
    ADD CONSTRAINT affiliated_with_pkey PRIMARY KEY (physician, department);


--
-- Name: appointment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT appointment_pkey PRIMARY KEY (appointmentid);


--
-- Name: asst_referee_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asst_referee_mast
    ADD CONSTRAINT asst_referee_mast_pkey PRIMARY KEY (ass_ref_id);


--
-- Name: block_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.block
    ADD CONSTRAINT block_pkey PRIMARY KEY (blockfloor, blockcode);


--
-- Name: casino_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.casino
    ADD CONSTRAINT casino_pkey PRIMARY KEY (casino);


--
-- Name: coach_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coach_mast
    ADD CONSTRAINT coach_mast_pkey PRIMARY KEY (coach_id);


--
-- Name: company_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company_mast
    ADD CONSTRAINT company_mast_pkey PRIMARY KEY (com_id);


--
-- Name: customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (customer_id);


--
-- Name: department_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (departmentid);


--
-- Name: departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (department_id);


--
-- Name: director_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.director
    ADD CONSTRAINT director_pkey PRIMARY KEY (dir_id);


--
-- Name: elephants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elephants
    ADD CONSTRAINT elephants_pkey PRIMARY KEY (id);


--
-- Name: emp_department_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emp_department
    ADD CONSTRAINT emp_department_pkey PRIMARY KEY (dpt_code);


--
-- Name: emp_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emp_details
    ADD CONSTRAINT emp_details_pkey PRIMARY KEY (emp_idno);


--
-- Name: emp_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emp
    ADD CONSTRAINT emp_pk PRIMARY KEY (eid);


--
-- Name: employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (employee_id);


--
-- Name: game_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_scores
    ADD CONSTRAINT game_scores_pkey PRIMARY KEY (id);


--
-- Name: genres_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT genres_pkey PRIMARY KEY (gen_id);


--
-- Name: goal_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_details
    ADD CONSTRAINT goal_details_pkey PRIMARY KEY (goal_id);


--
-- Name: grades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_pkey PRIMARY KEY (id);


--
-- Name: item_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_mast
    ADD CONSTRAINT item_mast_pkey PRIMARY KEY (pro_id);


--
-- Name: job_grades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_grades
    ADD CONSTRAINT job_grades_pkey PRIMARY KEY (grade_level);


--
-- Name: job_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_history
    ADD CONSTRAINT job_history_pkey PRIMARY KEY (employee_id, start_date);


--
-- Name: jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (job_id);


--
-- Name: locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- Name: manufacturers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.manufacturers
    ADD CONSTRAINT manufacturers_pkey PRIMARY KEY (code);


--
-- Name: match_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_mast
    ADD CONSTRAINT match_mast_pkey PRIMARY KEY (match_no);


--
-- Name: medication_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medication
    ADD CONSTRAINT medication_pkey PRIMARY KEY (code);


--
-- Name: movie_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie
    ADD CONSTRAINT movie_pkey PRIMARY KEY (mov_id);


--
-- Name: mytest1_ord_num_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mytest1
    ADD CONSTRAINT mytest1_ord_num_key UNIQUE (ord_num);


--
-- Name: mytest_ord_num_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mytest
    ADD CONSTRAINT mytest_ord_num_key UNIQUE (ord_num);


--
-- Name: nurse_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nurse
    ADD CONSTRAINT nurse_pkey PRIMARY KEY (employeeid);


--
-- Name: on_call_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.on_call
    ADD CONSTRAINT on_call_pkey PRIMARY KEY (nurse, blockfloor, blockcode, oncallstart, oncallend);


--
-- Name: orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (ord_no);


--
-- Name: partest1_ord_num_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partest1
    ADD CONSTRAINT partest1_ord_num_key UNIQUE (ord_num);


--
-- Name: patient_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (ssn);


--
-- Name: penalty_shootout_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_shootout
    ADD CONSTRAINT penalty_shootout_pkey PRIMARY KEY (kick_id);


--
-- Name: physician_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.physician
    ADD CONSTRAINT physician_pkey PRIMARY KEY (employeeid);


--
-- Name: player_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_mast
    ADD CONSTRAINT player_mast_pkey PRIMARY KEY (player_id);


--
-- Name: playing_position_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playing_position
    ADD CONSTRAINT playing_position_pkey PRIMARY KEY (position_id);


--
-- Name: prescribes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescribes
    ADD CONSTRAINT prescribes_pkey PRIMARY KEY (physician, patient, medication, date);


--
-- Name: procedure_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.procedure
    ADD CONSTRAINT procedure_pkey PRIMARY KEY (code);


--
-- Name: referee_mast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referee_mast
    ADD CONSTRAINT referee_mast_pkey PRIMARY KEY (referee_id);


--
-- Name: regions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (region_id);


--
-- Name: reviewer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviewer
    ADD CONSTRAINT reviewer_pkey PRIMARY KEY (rev_id);


--
-- Name: room_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (roomnumber);


--
-- Name: salesman_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.salesman
    ADD CONSTRAINT salesman_pkey PRIMARY KEY (salesman_id);


--
-- Name: scores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scores
    ADD CONSTRAINT scores_pkey PRIMARY KEY (id);


--
-- Name: soccer_city_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soccer_city
    ADD CONSTRAINT soccer_city_pkey PRIMARY KEY (city_id);


--
-- Name: soccer_country_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soccer_country
    ADD CONSTRAINT soccer_country_pkey PRIMARY KEY (country_id);


--
-- Name: soccer_venue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soccer_venue
    ADD CONSTRAINT soccer_venue_pkey PRIMARY KEY (venue_id);


--
-- Name: stay_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT stay_pkey PRIMARY KEY (stayid);


--
-- Name: sybba_ord_num_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sybba
    ADD CONSTRAINT sybba_ord_num_key UNIQUE (ord_num);


--
-- Name: trained_in_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trained_in
    ADD CONSTRAINT trained_in_pkey PRIMARY KEY (physician, treatment);


--
-- Name: undergoes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.undergoes
    ADD CONSTRAINT undergoes_pkey PRIMARY KEY (patient, procedure, stay, date);


--
-- Name: zebras_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zebras
    ADD CONSTRAINT zebras_pkey PRIMARY KEY (id);


--
-- Name: ass_ref_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_details
    ADD CONSTRAINT ass_ref_fkey FOREIGN KEY (ass_ref) REFERENCES public.asst_referee_mast(ass_ref_id);


--
-- Name: city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soccer_venue
    ADD CONSTRAINT city_id_fkey FOREIGN KEY (city_id) REFERENCES public.soccer_city(city_id);


--
-- Name: coach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_coaches
    ADD CONSTRAINT coach_id_fkey FOREIGN KEY (coach_id) REFERENCES public.coach_mast(coach_id);


--
-- Name: country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soccer_city
    ADD CONSTRAINT country_id_fkey FOREIGN KEY (country_id) REFERENCES public.soccer_country(country_id);


--
-- Name: country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.referee_mast
    ADD CONSTRAINT country_id_fkey FOREIGN KEY (country_id) REFERENCES public.soccer_country(country_id);


--
-- Name: country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asst_referee_mast
    ADD CONSTRAINT country_id_fkey FOREIGN KEY (country_id) REFERENCES public.soccer_country(country_id);


--
-- Name: customer_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT customer_id_fk FOREIGN KEY (customer_id) REFERENCES public.customer(customer_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: emp_details_emp_dept_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emp_details
    ADD CONSTRAINT emp_details_emp_dept_fkey FOREIGN KEY (emp_dept) REFERENCES public.emp_department(dpt_code);


--
-- Name: fk_appointment_appointmentid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescribes
    ADD CONSTRAINT fk_appointment_appointmentid FOREIGN KEY (appointment) REFERENCES public.appointment(appointmentid);


--
-- Name: fk_department_departmentid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.affiliated_with
    ADD CONSTRAINT fk_department_departmentid FOREIGN KEY (department) REFERENCES public.department(departmentid);


--
-- Name: fk_medication_code; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescribes
    ADD CONSTRAINT fk_medication_code FOREIGN KEY (medication) REFERENCES public.medication(code);


--
-- Name: fk_nurse_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT fk_nurse_employeeid FOREIGN KEY (prepnurse) REFERENCES public.nurse(employeeid);


--
-- Name: fk_nurse_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.undergoes
    ADD CONSTRAINT fk_nurse_employeeid FOREIGN KEY (assistingnurse) REFERENCES public.nurse(employeeid);


--
-- Name: fk_oncall_block_floor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.on_call
    ADD CONSTRAINT fk_oncall_block_floor FOREIGN KEY (blockfloor, blockcode) REFERENCES public.block(blockfloor, blockcode);


--
-- Name: fk_oncall_nurse_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.on_call
    ADD CONSTRAINT fk_oncall_nurse_employeeid FOREIGN KEY (nurse) REFERENCES public.nurse(employeeid);


--
-- Name: fk_patient_ssn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT fk_patient_ssn FOREIGN KEY (patient) REFERENCES public.patient(ssn);


--
-- Name: fk_patient_ssn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescribes
    ADD CONSTRAINT fk_patient_ssn FOREIGN KEY (patient) REFERENCES public.patient(ssn);


--
-- Name: fk_patient_ssn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT fk_patient_ssn FOREIGN KEY (patient) REFERENCES public.patient(ssn);


--
-- Name: fk_patient_ssn; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.undergoes
    ADD CONSTRAINT fk_patient_ssn FOREIGN KEY (patient) REFERENCES public.patient(ssn);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.department
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (head) REFERENCES public.physician(employeeid);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.affiliated_with
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (physician) REFERENCES public.physician(employeeid);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trained_in
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (physician) REFERENCES public.physician(employeeid);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (pcp) REFERENCES public.physician(employeeid);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointment
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (physician) REFERENCES public.physician(employeeid);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescribes
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (physician) REFERENCES public.physician(employeeid);


--
-- Name: fk_physician_employeeid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.undergoes
    ADD CONSTRAINT fk_physician_employeeid FOREIGN KEY (physician) REFERENCES public.physician(employeeid);


--
-- Name: fk_procedure_code; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trained_in
    ADD CONSTRAINT fk_procedure_code FOREIGN KEY (treatment) REFERENCES public.procedure(code);


--
-- Name: fk_procedure_code; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.undergoes
    ADD CONSTRAINT fk_procedure_code FOREIGN KEY (procedure) REFERENCES public.procedure(code);


--
-- Name: fk_room_block_pk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT fk_room_block_pk FOREIGN KEY (blockfloor, blockcode) REFERENCES public.block(blockfloor, blockcode);


--
-- Name: fk_room_number; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stay
    ADD CONSTRAINT fk_room_number FOREIGN KEY (room) REFERENCES public.room(roomnumber);


--
-- Name: fk_stay_stayid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.undergoes
    ADD CONSTRAINT fk_stay_stayid FOREIGN KEY (stay) REFERENCES public.stay(stayid);


--
-- Name: item_mast_pro_com_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item_mast
    ADD CONSTRAINT item_mast_pro_com_fkey FOREIGN KEY (pro_com) REFERENCES public.company_mast(com_id);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_details
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_booked
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_in_out
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_shootout
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_details
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_captain
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: match_no_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_gk
    ADD CONSTRAINT match_no_fkey FOREIGN KEY (match_no) REFERENCES public.match_mast(match_no);


--
-- Name: movie_cast_act_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie_cast
    ADD CONSTRAINT movie_cast_act_id_fkey FOREIGN KEY (act_id) REFERENCES public.actor(act_id);


--
-- Name: movie_cast_mov_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie_cast
    ADD CONSTRAINT movie_cast_mov_id_fkey FOREIGN KEY (mov_id) REFERENCES public.movie(mov_id);


--
-- Name: movie_direction_dir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie_direction
    ADD CONSTRAINT movie_direction_dir_id_fkey FOREIGN KEY (dir_id) REFERENCES public.director(dir_id);


--
-- Name: movie_direction_mov_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie_direction
    ADD CONSTRAINT movie_direction_mov_id_fkey FOREIGN KEY (mov_id) REFERENCES public.movie(mov_id);


--
-- Name: movie_genres_gen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie_genres
    ADD CONSTRAINT movie_genres_gen_id_fkey FOREIGN KEY (gen_id) REFERENCES public.genres(gen_id);


--
-- Name: movie_genres_mov_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movie_genres
    ADD CONSTRAINT movie_genres_mov_id_fkey FOREIGN KEY (mov_id) REFERENCES public.movie(mov_id);


--
-- Name: player_captain_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_captain
    ADD CONSTRAINT player_captain_fkey FOREIGN KEY (player_captain) REFERENCES public.player_mast(player_id);


--
-- Name: player_gk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_details
    ADD CONSTRAINT player_gk_fkey FOREIGN KEY (player_gk) REFERENCES public.player_mast(player_id);


--
-- Name: player_gk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_gk
    ADD CONSTRAINT player_gk_fkey FOREIGN KEY (player_gk) REFERENCES public.player_mast(player_id);


--
-- Name: player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_booked
    ADD CONSTRAINT player_id_fkey FOREIGN KEY (player_id) REFERENCES public.player_mast(player_id);


--
-- Name: player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_in_out
    ADD CONSTRAINT player_id_fkey FOREIGN KEY (player_id) REFERENCES public.player_mast(player_id);


--
-- Name: player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_shootout
    ADD CONSTRAINT player_id_fkey FOREIGN KEY (player_id) REFERENCES public.player_mast(player_id);


--
-- Name: player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_details
    ADD CONSTRAINT player_id_fkey FOREIGN KEY (player_id) REFERENCES public.player_mast(player_id);


--
-- Name: plr_of_match_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_mast
    ADD CONSTRAINT plr_of_match_fkey FOREIGN KEY (plr_of_match) REFERENCES public.player_mast(player_id);


--
-- Name: posi_to_play_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_mast
    ADD CONSTRAINT posi_to_play_fkey FOREIGN KEY (posi_to_play) REFERENCES public.playing_position(position_id);


--
-- Name: rating_mov_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_mov_id_fkey FOREIGN KEY (mov_id) REFERENCES public.movie(mov_id);


--
-- Name: rating_rev_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_rev_id_fkey FOREIGN KEY (rev_id) REFERENCES public.reviewer(rev_id);


--
-- Name: referee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_mast
    ADD CONSTRAINT referee_id_fkey FOREIGN KEY (referee_id) REFERENCES public.referee_mast(referee_id);


--
-- Name: salesman_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT salesman_id_fk FOREIGN KEY (salesman_id) REFERENCES public.salesman(salesman_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: salesman_id_fk2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT salesman_id_fk2 FOREIGN KEY (salesman_id) REFERENCES public.salesman(salesman_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_coaches
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_mast
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.soccer_team
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_details
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_booked
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_in_out
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_shootout
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_details
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_captain
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.penalty_gk
    ADD CONSTRAINT team_id_fkey FOREIGN KEY (team_id) REFERENCES public.soccer_country(country_id);


--
-- Name: venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_mast
    ADD CONSTRAINT venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.soccer_venue(venue_id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO postgres;


--
-- Name: TABLE actor; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.actor FROM PUBLIC;
REVOKE ALL ON TABLE public.actor FROM postgres;
GRANT ALL ON TABLE public.actor TO postgres;
GRANT SELECT ON TABLE public.actor TO postgres;


--
-- Name: TABLE address; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.address FROM PUBLIC;
REVOKE ALL ON TABLE public.address FROM postgres;
GRANT ALL ON TABLE public.address TO postgres;
GRANT SELECT ON TABLE public.address TO postgres;


--
-- Name: TABLE affiliated_with; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.affiliated_with FROM PUBLIC;
REVOKE ALL ON TABLE public.affiliated_with FROM postgres;
GRANT ALL ON TABLE public.affiliated_with TO postgres;
GRANT SELECT ON TABLE public.affiliated_with TO postgres;


--
-- Name: TABLE customer; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.customer FROM PUBLIC;
REVOKE ALL ON TABLE public.customer FROM postgres;
GRANT ALL ON TABLE public.customer TO postgres;
GRANT SELECT ON TABLE public.customer TO postgres;


--
-- Name: TABLE agentview; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.agentview FROM PUBLIC;
REVOKE ALL ON TABLE public.agentview FROM postgres;
GRANT ALL ON TABLE public.agentview TO postgres;
GRANT SELECT ON TABLE public.agentview TO postgres;


--
-- Name: TABLE appointment; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.appointment FROM PUBLIC;
REVOKE ALL ON TABLE public.appointment FROM postgres;
GRANT ALL ON TABLE public.appointment TO postgres;
GRANT SELECT ON TABLE public.appointment TO postgres;


--
-- Name: TABLE asst_referee_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.asst_referee_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.asst_referee_mast FROM postgres;
GRANT ALL ON TABLE public.asst_referee_mast TO postgres;
GRANT SELECT ON TABLE public.asst_referee_mast TO postgres;


--
-- Name: TABLE bh; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.bh FROM PUBLIC;
REVOKE ALL ON TABLE public.bh FROM postgres;
GRANT ALL ON TABLE public.bh TO postgres;
GRANT SELECT ON TABLE public.bh TO postgres;


--
-- Name: TABLE block; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.block FROM PUBLIC;
REVOKE ALL ON TABLE public.block FROM postgres;
GRANT ALL ON TABLE public.block TO postgres;
GRANT SELECT ON TABLE public.block TO postgres;


--
-- Name: TABLE casino; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.casino FROM PUBLIC;
REVOKE ALL ON TABLE public.casino FROM postgres;
GRANT ALL ON TABLE public.casino TO postgres;
GRANT SELECT ON TABLE public.casino TO postgres;


--
-- Name: TABLE coach_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.coach_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.coach_mast FROM postgres;
GRANT ALL ON TABLE public.coach_mast TO postgres;
GRANT SELECT ON TABLE public.coach_mast TO postgres;


--
-- Name: TABLE col1; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.col1 FROM PUBLIC;
REVOKE ALL ON TABLE public.col1 FROM postgres;
GRANT ALL ON TABLE public.col1 TO postgres;
GRANT SELECT ON TABLE public.col1 TO postgres;


--
-- Name: TABLE company_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.company_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.company_mast FROM postgres;
GRANT ALL ON TABLE public.company_mast TO postgres;
GRANT SELECT ON TABLE public.company_mast TO PUBLIC;


--
-- Name: TABLE countries; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.countries FROM PUBLIC;
REVOKE ALL ON TABLE public.countries FROM postgres;
GRANT ALL ON TABLE public.countries TO postgres;
GRANT SELECT ON TABLE public.countries TO postgres;


--
-- Name: TABLE customer_backup; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.customer_backup FROM PUBLIC;
REVOKE ALL ON TABLE public.customer_backup FROM postgres;
GRANT ALL ON TABLE public.customer_backup TO postgres;
GRANT SELECT ON TABLE public.customer_backup TO postgres;


--
-- Name: TABLE customergradelevels; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.customergradelevels FROM PUBLIC;
REVOKE ALL ON TABLE public.customergradelevels FROM postgres;
GRANT ALL ON TABLE public.customergradelevels TO postgres;
GRANT SELECT ON TABLE public.customergradelevels TO postgres;


--
-- Name: TABLE customergradelevels2; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.customergradelevels2 FROM PUBLIC;
REVOKE ALL ON TABLE public.customergradelevels2 FROM postgres;
GRANT ALL ON TABLE public.customergradelevels2 TO postgres;
GRANT SELECT ON TABLE public.customergradelevels2 TO postgres;


--
-- Name: TABLE department; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.department FROM PUBLIC;
REVOKE ALL ON TABLE public.department FROM postgres;
GRANT ALL ON TABLE public.department TO postgres;
GRANT SELECT ON TABLE public.department TO postgres;


--
-- Name: TABLE departments; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.departments FROM PUBLIC;
REVOKE ALL ON TABLE public.departments FROM postgres;
GRANT ALL ON TABLE public.departments TO postgres;
GRANT SELECT ON TABLE public.departments TO postgres;


--
-- Name: TABLE director; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.director FROM PUBLIC;
REVOKE ALL ON TABLE public.director FROM postgres;
GRANT ALL ON TABLE public.director TO postgres;
GRANT SELECT ON TABLE public.director TO postgres;


--
-- Name: TABLE elephants; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.elephants FROM PUBLIC;
REVOKE ALL ON TABLE public.elephants FROM postgres;
GRANT ALL ON TABLE public.elephants TO postgres;
GRANT SELECT ON TABLE public.elephants TO postgres;


--
-- Name: TABLE emp; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.emp FROM PUBLIC;
REVOKE ALL ON TABLE public.emp FROM postgres;
GRANT ALL ON TABLE public.emp TO postgres;
GRANT SELECT ON TABLE public.emp TO postgres;


--
-- Name: TABLE emp_department; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.emp_department FROM PUBLIC;
REVOKE ALL ON TABLE public.emp_department FROM postgres;
GRANT ALL ON TABLE public.emp_department TO postgres;
GRANT SELECT ON TABLE public.emp_department TO PUBLIC;


--
-- Name: TABLE emp_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.emp_details FROM PUBLIC;
REVOKE ALL ON TABLE public.emp_details FROM postgres;
GRANT ALL ON TABLE public.emp_details TO postgres;
GRANT SELECT ON TABLE public.emp_details TO PUBLIC;


--
-- Name: TABLE employee; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.employee FROM PUBLIC;
REVOKE ALL ON TABLE public.employee FROM postgres;
GRANT ALL ON TABLE public.employee TO postgres;
GRANT SELECT ON TABLE public.employee TO postgres;


--
-- Name: TABLE employees; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.employees FROM PUBLIC;
REVOKE ALL ON TABLE public.employees FROM postgres;
GRANT ALL ON TABLE public.employees TO postgres;
GRANT SELECT ON TABLE public.employees TO postgres;


--
-- Name: TABLE game_scores; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.game_scores FROM PUBLIC;
REVOKE ALL ON TABLE public.game_scores FROM postgres;
GRANT ALL ON TABLE public.game_scores TO postgres;
GRANT SELECT ON TABLE public.game_scores TO postgres;


--
-- Name: TABLE genres; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.genres FROM PUBLIC;
REVOKE ALL ON TABLE public.genres FROM postgres;
GRANT ALL ON TABLE public.genres TO postgres;
GRANT SELECT ON TABLE public.genres TO postgres;


--
-- Name: TABLE goal_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.goal_details FROM PUBLIC;
REVOKE ALL ON TABLE public.goal_details FROM postgres;
GRANT ALL ON TABLE public.goal_details TO postgres;
GRANT SELECT ON TABLE public.goal_details TO postgres;


--
-- Name: TABLE grade; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.grade FROM PUBLIC;
REVOKE ALL ON TABLE public.grade FROM postgres;
GRANT ALL ON TABLE public.grade TO postgres;
GRANT SELECT ON TABLE public.grade TO postgres;


--
-- Name: TABLE grade_customer; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.grade_customer FROM PUBLIC;
REVOKE ALL ON TABLE public.grade_customer FROM postgres;
GRANT ALL ON TABLE public.grade_customer TO postgres;
GRANT SELECT ON TABLE public.grade_customer TO postgres;


--
-- Name: TABLE grade_customer1; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.grade_customer1 FROM PUBLIC;
REVOKE ALL ON TABLE public.grade_customer1 FROM postgres;
GRANT ALL ON TABLE public.grade_customer1 TO postgres;
GRANT SELECT ON TABLE public.grade_customer1 TO postgres;


--
-- Name: TABLE grades; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.grades FROM PUBLIC;
REVOKE ALL ON TABLE public.grades FROM postgres;
GRANT ALL ON TABLE public.grades TO postgres;
GRANT SELECT ON TABLE public.grades TO postgres;


--
-- Name: TABLE hello; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.hello FROM PUBLIC;
REVOKE ALL ON TABLE public.hello FROM postgres;
GRANT ALL ON TABLE public.hello TO postgres;
GRANT SELECT ON TABLE public.hello TO postgres;


--
-- Name: TABLE hello1_1122; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.hello1_1122 FROM PUBLIC;
REVOKE ALL ON TABLE public.hello1_1122 FROM postgres;
GRANT ALL ON TABLE public.hello1_1122 TO postgres;
GRANT SELECT ON TABLE public.hello1_1122 TO postgres;


--
-- Name: TABLE hello1_12; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.hello1_12 FROM PUBLIC;
REVOKE ALL ON TABLE public.hello1_12 FROM postgres;
GRANT ALL ON TABLE public.hello1_12 TO postgres;
GRANT SELECT ON TABLE public.hello1_12 TO postgres;


--
-- Name: TABLE hello_12; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.hello_12 FROM PUBLIC;
REVOKE ALL ON TABLE public.hello_12 FROM postgres;
GRANT ALL ON TABLE public.hello_12 TO postgres;
GRANT SELECT ON TABLE public.hello_12 TO postgres;


--
-- Name: TABLE item_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.item_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.item_mast FROM postgres;
GRANT ALL ON TABLE public.item_mast TO postgres;
GRANT SELECT ON TABLE public.item_mast TO PUBLIC;


--
-- Name: TABLE job_grades; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.job_grades FROM PUBLIC;
REVOKE ALL ON TABLE public.job_grades FROM postgres;
GRANT ALL ON TABLE public.job_grades TO postgres;
GRANT SELECT ON TABLE public.job_grades TO postgres;


--
-- Name: TABLE job_history; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.job_history FROM PUBLIC;
REVOKE ALL ON TABLE public.job_history FROM postgres;
GRANT ALL ON TABLE public.job_history TO postgres;
GRANT SELECT ON TABLE public.job_history TO postgres;


--
-- Name: TABLE jobs; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.jobs FROM PUBLIC;
REVOKE ALL ON TABLE public.jobs FROM postgres;
GRANT ALL ON TABLE public.jobs TO postgres;
GRANT SELECT ON TABLE public.jobs TO postgres;


--
-- Name: TABLE locations; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.locations FROM PUBLIC;
REVOKE ALL ON TABLE public.locations FROM postgres;
GRANT ALL ON TABLE public.locations TO postgres;
GRANT SELECT ON TABLE public.locations TO postgres;


--
-- Name: TABLE match_captain; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.match_captain FROM PUBLIC;
REVOKE ALL ON TABLE public.match_captain FROM postgres;
GRANT ALL ON TABLE public.match_captain TO postgres;
GRANT SELECT ON TABLE public.match_captain TO postgres;


--
-- Name: TABLE match_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.match_details FROM PUBLIC;
REVOKE ALL ON TABLE public.match_details FROM postgres;
GRANT ALL ON TABLE public.match_details TO postgres;
GRANT SELECT ON TABLE public.match_details TO postgres;


--
-- Name: TABLE match_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.match_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.match_mast FROM postgres;
GRANT ALL ON TABLE public.match_mast TO postgres;
GRANT SELECT ON TABLE public.match_mast TO postgres;


--
-- Name: TABLE maxim00; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.maxim00 FROM PUBLIC;
REVOKE ALL ON TABLE public.maxim00 FROM postgres;
GRANT ALL ON TABLE public.maxim00 TO postgres;
GRANT SELECT ON TABLE public.maxim00 TO postgres;


--
-- Name: TABLE maximum; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.maximum FROM PUBLIC;
REVOKE ALL ON TABLE public.maximum FROM postgres;
GRANT ALL ON TABLE public.maximum TO postgres;
GRANT SELECT ON TABLE public.maximum TO postgres;


--
-- Name: TABLE maximum00; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.maximum00 FROM PUBLIC;
REVOKE ALL ON TABLE public.maximum00 FROM postgres;
GRANT ALL ON TABLE public.maximum00 TO postgres;
GRANT SELECT ON TABLE public.maximum00 TO postgres;


--
-- Name: TABLE maximum899; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.maximum899 FROM PUBLIC;
REVOKE ALL ON TABLE public.maximum899 FROM postgres;
GRANT ALL ON TABLE public.maximum899 TO postgres;
GRANT SELECT ON TABLE public.maximum899 TO postgres;


--
-- Name: TABLE medication; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.medication FROM PUBLIC;
REVOKE ALL ON TABLE public.medication FROM postgres;
GRANT ALL ON TABLE public.medication TO postgres;
GRANT SELECT ON TABLE public.medication TO postgres;


--
-- Name: TABLE movie; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.movie FROM PUBLIC;
REVOKE ALL ON TABLE public.movie FROM postgres;
GRANT ALL ON TABLE public.movie TO postgres;
GRANT SELECT ON TABLE public.movie TO postgres;


--
-- Name: TABLE movie_cast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.movie_cast FROM PUBLIC;
REVOKE ALL ON TABLE public.movie_cast FROM postgres;
GRANT ALL ON TABLE public.movie_cast TO postgres;
GRANT SELECT ON TABLE public.movie_cast TO postgres;


--
-- Name: TABLE movie_direction; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.movie_direction FROM PUBLIC;
REVOKE ALL ON TABLE public.movie_direction FROM postgres;
GRANT ALL ON TABLE public.movie_direction TO postgres;
GRANT SELECT ON TABLE public.movie_direction TO postgres;


--
-- Name: TABLE movie_genres; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.movie_genres FROM PUBLIC;
REVOKE ALL ON TABLE public.movie_genres FROM postgres;
GRANT ALL ON TABLE public.movie_genres TO postgres;
GRANT SELECT ON TABLE public.movie_genres TO postgres;


--
-- Name: TABLE mytest; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.mytest FROM PUBLIC;
REVOKE ALL ON TABLE public.mytest FROM postgres;
GRANT ALL ON TABLE public.mytest TO postgres;
GRANT SELECT ON TABLE public.mytest TO postgres;


--
-- Name: TABLE mytest1; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.mytest1 FROM PUBLIC;
REVOKE ALL ON TABLE public.mytest1 FROM postgres;
GRANT ALL ON TABLE public.mytest1 TO postgres;
GRANT SELECT ON TABLE public.mytest1 TO postgres;


--
-- Name: TABLE salesman; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesman FROM PUBLIC;
REVOKE ALL ON TABLE public.salesman FROM postgres;
GRANT ALL ON TABLE public.salesman TO postgres;
GRANT SELECT ON TABLE public.salesman TO postgres;


--
-- Name: TABLE myworkstuff; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.myworkstuff FROM PUBLIC;
REVOKE ALL ON TABLE public.myworkstuff FROM postgres;
GRANT ALL ON TABLE public.myworkstuff TO postgres;
GRANT SELECT ON TABLE public.myworkstuff TO postgres;


--
-- Name: TABLE myworkstuffs; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.myworkstuffs FROM PUBLIC;
REVOKE ALL ON TABLE public.myworkstuffs FROM postgres;
GRANT ALL ON TABLE public.myworkstuffs TO postgres;
GRANT SELECT ON TABLE public.myworkstuffs TO postgres;


--
-- Name: TABLE new; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.new FROM PUBLIC;
REVOKE ALL ON TABLE public.new FROM postgres;
GRANT ALL ON TABLE public.new TO postgres;
GRANT SELECT ON TABLE public.new TO postgres;


--
-- Name: TABLE new123; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.new123 FROM PUBLIC;
REVOKE ALL ON TABLE public.new123 FROM postgres;
GRANT ALL ON TABLE public.new123 TO postgres;
GRANT SELECT ON TABLE public.new123 TO postgres;


--
-- Name: TABLE new_table; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.new_table FROM PUBLIC;
REVOKE ALL ON TABLE public.new_table FROM postgres;
GRANT ALL ON TABLE public.new_table TO postgres;
GRANT SELECT ON TABLE public.new_table TO postgres;


--
-- Name: TABLE newtab; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.newtab FROM PUBLIC;
REVOKE ALL ON TABLE public.newtab FROM postgres;
GRANT ALL ON TABLE public.newtab TO postgres;
GRANT SELECT ON TABLE public.newtab TO postgres;


--
-- Name: TABLE newyorksalesman; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.newyorksalesman FROM PUBLIC;
REVOKE ALL ON TABLE public.newyorksalesman FROM postgres;
GRANT ALL ON TABLE public.newyorksalesman TO postgres;
GRANT SELECT ON TABLE public.newyorksalesman TO postgres;


--
-- Name: TABLE newyorksalesman2; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.newyorksalesman2 FROM PUBLIC;
REVOKE ALL ON TABLE public.newyorksalesman2 FROM postgres;
GRANT ALL ON TABLE public.newyorksalesman2 TO postgres;
GRANT SELECT ON TABLE public.newyorksalesman2 TO postgres;


--
-- Name: TABLE newyorksalesman3; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.newyorksalesman3 FROM PUBLIC;
REVOKE ALL ON TABLE public.newyorksalesman3 FROM postgres;
GRANT ALL ON TABLE public.newyorksalesman3 TO postgres;
GRANT SELECT ON TABLE public.newyorksalesman3 TO postgres;


--
-- Name: TABLE newyorkstaff; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.newyorkstaff FROM PUBLIC;
REVOKE ALL ON TABLE public.newyorkstaff FROM postgres;
GRANT ALL ON TABLE public.newyorkstaff TO postgres;
GRANT SELECT ON TABLE public.newyorkstaff TO postgres;


--
-- Name: TABLE nobel_win; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.nobel_win FROM PUBLIC;
REVOKE ALL ON TABLE public.nobel_win FROM postgres;
GRANT ALL ON TABLE public.nobel_win TO postgres;
GRANT SELECT ON TABLE public.nobel_win TO PUBLIC;


--
-- Name: TABLE orders; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.orders FROM PUBLIC;
REVOKE ALL ON TABLE public.orders FROM postgres;
GRANT ALL ON TABLE public.orders TO postgres;
GRANT SELECT ON TABLE public.orders TO postgres;


--
-- Name: TABLE norders; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.norders FROM PUBLIC;
REVOKE ALL ON TABLE public.norders FROM postgres;
GRANT ALL ON TABLE public.norders TO postgres;
GRANT SELECT ON TABLE public.norders TO postgres;


--
-- Name: TABLE nros; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.nros FROM PUBLIC;
REVOKE ALL ON TABLE public.nros FROM postgres;
GRANT ALL ON TABLE public.nros TO postgres;
GRANT SELECT ON TABLE public.nros TO postgres;


--
-- Name: TABLE nuevo; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.nuevo FROM PUBLIC;
REVOKE ALL ON TABLE public.nuevo FROM postgres;
GRANT ALL ON TABLE public.nuevo TO postgres;
GRANT SELECT ON TABLE public.nuevo TO postgres;


--
-- Name: TABLE numbers; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.numbers FROM PUBLIC;
REVOKE ALL ON TABLE public.numbers FROM postgres;
GRANT ALL ON TABLE public.numbers TO postgres;
GRANT SELECT ON TABLE public.numbers TO postgres;


--
-- Name: TABLE numeri; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.numeri FROM PUBLIC;
REVOKE ALL ON TABLE public.numeri FROM postgres;
GRANT ALL ON TABLE public.numeri TO postgres;
GRANT SELECT ON TABLE public.numeri TO postgres;


--
-- Name: TABLE numeros; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.numeros FROM PUBLIC;
REVOKE ALL ON TABLE public.numeros FROM postgres;
GRANT ALL ON TABLE public.numeros TO postgres;
GRANT SELECT ON TABLE public.numeros TO postgres;


--
-- Name: TABLE nurse; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.nurse FROM PUBLIC;
REVOKE ALL ON TABLE public.nurse FROM postgres;
GRANT ALL ON TABLE public.nurse TO postgres;
GRANT SELECT ON TABLE public.nurse TO postgres;


--
-- Name: TABLE odr; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.odr FROM PUBLIC;
REVOKE ALL ON TABLE public.odr FROM postgres;
GRANT ALL ON TABLE public.odr TO postgres;
GRANT SELECT ON TABLE public.odr TO postgres;


--
-- Name: TABLE on_call; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.on_call FROM PUBLIC;
REVOKE ALL ON TABLE public.on_call FROM postgres;
GRANT ALL ON TABLE public.on_call TO postgres;
GRANT SELECT ON TABLE public.on_call TO postgres;


--
-- Name: TABLE orozco; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.orozco FROM PUBLIC;
REVOKE ALL ON TABLE public.orozco FROM postgres;
GRANT ALL ON TABLE public.orozco TO postgres;
GRANT SELECT ON TABLE public.orozco TO postgres;


--
-- Name: TABLE partest1; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.partest1 FROM PUBLIC;
REVOKE ALL ON TABLE public.partest1 FROM postgres;
GRANT ALL ON TABLE public.partest1 TO postgres;
GRANT SELECT ON TABLE public.partest1 TO postgres;


--
-- Name: TABLE participant; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.participant FROM PUBLIC;
REVOKE ALL ON TABLE public.participant FROM postgres;
GRANT ALL ON TABLE public.participant TO postgres;
GRANT SELECT ON TABLE public.participant TO postgres;


--
-- Name: TABLE participants; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.participants FROM PUBLIC;
REVOKE ALL ON TABLE public.participants FROM postgres;
GRANT ALL ON TABLE public.participants TO postgres;
GRANT SELECT ON TABLE public.participants TO postgres;


--
-- Name: TABLE patient; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.patient FROM PUBLIC;
REVOKE ALL ON TABLE public.patient FROM postgres;
GRANT ALL ON TABLE public.patient TO postgres;
GRANT SELECT ON TABLE public.patient TO postgres;


--
-- Name: TABLE penalty_gk; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.penalty_gk FROM PUBLIC;
REVOKE ALL ON TABLE public.penalty_gk FROM postgres;
GRANT ALL ON TABLE public.penalty_gk TO postgres;
GRANT SELECT ON TABLE public.penalty_gk TO postgres;


--
-- Name: TABLE penalty_shootout; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.penalty_shootout FROM PUBLIC;
REVOKE ALL ON TABLE public.penalty_shootout FROM postgres;
GRANT ALL ON TABLE public.penalty_shootout TO postgres;
GRANT SELECT ON TABLE public.penalty_shootout TO postgres;


--
-- Name: TABLE persons; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.persons FROM PUBLIC;
REVOKE ALL ON TABLE public.persons FROM postgres;
GRANT ALL ON TABLE public.persons TO postgres;
GRANT SELECT ON TABLE public.persons TO postgres;


--
-- Name: TABLE physician; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.physician FROM PUBLIC;
REVOKE ALL ON TABLE public.physician FROM postgres;
GRANT ALL ON TABLE public.physician TO postgres;
GRANT SELECT ON TABLE public.physician TO postgres;


--
-- Name: TABLE player_booked; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.player_booked FROM PUBLIC;
REVOKE ALL ON TABLE public.player_booked FROM postgres;
GRANT ALL ON TABLE public.player_booked TO postgres;
GRANT SELECT ON TABLE public.player_booked TO postgres;


--
-- Name: TABLE player_in_out; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.player_in_out FROM PUBLIC;
REVOKE ALL ON TABLE public.player_in_out FROM postgres;
GRANT ALL ON TABLE public.player_in_out TO postgres;
GRANT SELECT ON TABLE public.player_in_out TO postgres;


--
-- Name: TABLE player_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.player_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.player_mast FROM postgres;
GRANT ALL ON TABLE public.player_mast TO postgres;
GRANT SELECT ON TABLE public.player_mast TO postgres;


--
-- Name: TABLE playing_position; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.playing_position FROM PUBLIC;
REVOKE ALL ON TABLE public.playing_position FROM postgres;
GRANT ALL ON TABLE public.playing_position TO postgres;
GRANT SELECT ON TABLE public.playing_position TO postgres;


--
-- Name: TABLE prescribes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.prescribes FROM PUBLIC;
REVOKE ALL ON TABLE public.prescribes FROM postgres;
GRANT ALL ON TABLE public.prescribes TO postgres;
GRANT SELECT ON TABLE public.prescribes TO postgres;


--
-- Name: TABLE procedure; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.procedure FROM PUBLIC;
REVOKE ALL ON TABLE public.procedure FROM postgres;
GRANT ALL ON TABLE public.procedure TO postgres;
GRANT SELECT ON TABLE public.procedure TO postgres;


--
-- Name: TABLE raster_overviews; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.raster_overviews FROM PUBLIC;
REVOKE ALL ON TABLE public.raster_overviews FROM postgres;
GRANT ALL ON TABLE public.raster_overviews TO postgres;
GRANT SELECT ON TABLE public.raster_overviews TO postgres;


--
-- Name: TABLE rating; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.rating FROM PUBLIC;
REVOKE ALL ON TABLE public.rating FROM postgres;
GRANT ALL ON TABLE public.rating TO postgres;
GRANT SELECT ON TABLE public.rating TO postgres;


--
-- Name: TABLE referee_mast; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.referee_mast FROM PUBLIC;
REVOKE ALL ON TABLE public.referee_mast FROM postgres;
GRANT ALL ON TABLE public.referee_mast TO postgres;
GRANT SELECT ON TABLE public.referee_mast TO postgres;


--
-- Name: TABLE regions; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.regions FROM PUBLIC;
REVOKE ALL ON TABLE public.regions FROM postgres;
GRANT ALL ON TABLE public.regions TO postgres;
GRANT SELECT ON TABLE public.regions TO postgres;


--
-- Name: TABLE related; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.related FROM PUBLIC;
REVOKE ALL ON TABLE public.related FROM postgres;
GRANT ALL ON TABLE public.related TO postgres;
GRANT SELECT ON TABLE public.related TO postgres;


--
-- Name: TABLE reviewer; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.reviewer FROM PUBLIC;
REVOKE ALL ON TABLE public.reviewer FROM postgres;
GRANT ALL ON TABLE public.reviewer TO postgres;
GRANT SELECT ON TABLE public.reviewer TO postgres;


--
-- Name: TABLE rightjoins; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.rightjoins FROM PUBLIC;
REVOKE ALL ON TABLE public.rightjoins FROM postgres;
GRANT ALL ON TABLE public.rightjoins TO postgres;
GRANT SELECT ON TABLE public.rightjoins TO postgres;


--
-- Name: TABLE room; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.room FROM PUBLIC;
REVOKE ALL ON TABLE public.room FROM postgres;
GRANT ALL ON TABLE public.room TO postgres;
GRANT SELECT ON TABLE public.room TO postgres;


--
-- Name: TABLE salesdetail; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesdetail FROM PUBLIC;
REVOKE ALL ON TABLE public.salesdetail FROM postgres;
GRANT ALL ON TABLE public.salesdetail TO postgres;
GRANT SELECT ON TABLE public.salesdetail TO postgres;


--
-- Name: TABLE salesman_detail; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesman_detail FROM PUBLIC;
REVOKE ALL ON TABLE public.salesman_detail FROM postgres;
GRANT ALL ON TABLE public.salesman_detail TO postgres;
GRANT SELECT ON TABLE public.salesman_detail TO postgres;


--
-- Name: TABLE salesman_do1304; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesman_do1304 FROM PUBLIC;
REVOKE ALL ON TABLE public.salesman_do1304 FROM postgres;
GRANT ALL ON TABLE public.salesman_do1304 TO postgres;
GRANT SELECT ON TABLE public.salesman_do1304 TO postgres;


--
-- Name: TABLE salesman_example; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesman_example FROM PUBLIC;
REVOKE ALL ON TABLE public.salesman_example FROM postgres;
GRANT ALL ON TABLE public.salesman_example TO postgres;
GRANT SELECT ON TABLE public.salesman_example TO postgres;


--
-- Name: TABLE salesman_ny; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesman_ny FROM PUBLIC;
REVOKE ALL ON TABLE public.salesman_ny FROM postgres;
GRANT ALL ON TABLE public.salesman_ny TO postgres;
GRANT SELECT ON TABLE public.salesman_ny TO postgres;


--
-- Name: TABLE salesmandetail; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesmandetail FROM PUBLIC;
REVOKE ALL ON TABLE public.salesmandetail FROM postgres;
GRANT ALL ON TABLE public.salesmandetail TO postgres;
GRANT SELECT ON TABLE public.salesmandetail TO postgres;


--
-- Name: TABLE salesown; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.salesown FROM PUBLIC;
REVOKE ALL ON TABLE public.salesown FROM postgres;
GRANT ALL ON TABLE public.salesown TO postgres;
GRANT SELECT ON TABLE public.salesown TO postgres;


--
-- Name: TABLE sample_table; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.sample_table FROM PUBLIC;
REVOKE ALL ON TABLE public.sample_table FROM postgres;
GRANT ALL ON TABLE public.sample_table TO postgres;
GRANT SELECT ON TABLE public.sample_table TO postgres;


--
-- Name: TABLE scores; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.scores FROM PUBLIC;
REVOKE ALL ON TABLE public.scores FROM postgres;
GRANT ALL ON TABLE public.scores TO postgres;
GRANT SELECT ON TABLE public.scores TO postgres;


--
-- Name: TABLE soccer_city; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.soccer_city FROM PUBLIC;
REVOKE ALL ON TABLE public.soccer_city FROM postgres;
GRANT ALL ON TABLE public.soccer_city TO postgres;
GRANT SELECT ON TABLE public.soccer_city TO postgres;


--
-- Name: TABLE soccer_country; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.soccer_country FROM PUBLIC;
REVOKE ALL ON TABLE public.soccer_country FROM postgres;
GRANT ALL ON TABLE public.soccer_country TO postgres;
GRANT SELECT ON TABLE public.soccer_country TO postgres;


--
-- Name: TABLE soccer_team; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.soccer_team FROM PUBLIC;
REVOKE ALL ON TABLE public.soccer_team FROM postgres;
GRANT ALL ON TABLE public.soccer_team TO postgres;
GRANT SELECT ON TABLE public.soccer_team TO postgres;


--
-- Name: TABLE soccer_venue; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.soccer_venue FROM PUBLIC;
REVOKE ALL ON TABLE public.soccer_venue FROM postgres;
GRANT ALL ON TABLE public.soccer_venue TO postgres;
GRANT SELECT ON TABLE public.soccer_venue TO postgres;


--
-- Name: TABLE statements; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.statements FROM PUBLIC;
REVOKE ALL ON TABLE public.statements FROM postgres;
GRANT ALL ON TABLE public.statements TO postgres;
GRANT SELECT ON TABLE public.statements TO postgres;


--
-- Name: TABLE stay; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.stay FROM PUBLIC;
REVOKE ALL ON TABLE public.stay FROM postgres;
GRANT ALL ON TABLE public.stay TO postgres;
GRANT SELECT ON TABLE public.stay TO postgres;


--
-- Name: TABLE student; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.student FROM PUBLIC;
REVOKE ALL ON TABLE public.student FROM postgres;
GRANT ALL ON TABLE public.student TO postgres;
GRANT SELECT ON TABLE public.student TO postgres;


--
-- Name: TABLE student1; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.student1 FROM PUBLIC;
REVOKE ALL ON TABLE public.student1 FROM postgres;
GRANT ALL ON TABLE public.student1 TO postgres;
GRANT SELECT ON TABLE public.student1 TO postgres;


--
-- Name: TABLE sybba; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.sybba FROM PUBLIC;
REVOKE ALL ON TABLE public.sybba FROM postgres;
GRANT ALL ON TABLE public.sybba TO postgres;
GRANT SELECT ON TABLE public.sybba TO postgres;


--
-- Name: TABLE team_coaches; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.team_coaches FROM PUBLIC;
REVOKE ALL ON TABLE public.team_coaches FROM postgres;
GRANT ALL ON TABLE public.team_coaches TO postgres;
GRANT SELECT ON TABLE public.team_coaches TO postgres;


--
-- Name: TABLE temp; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.temp FROM PUBLIC;
REVOKE ALL ON TABLE public.temp FROM postgres;
GRANT ALL ON TABLE public.temp TO postgres;
GRANT SELECT ON TABLE public.temp TO postgres;


--
-- Name: TABLE tempa; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.tempa FROM PUBLIC;
REVOKE ALL ON TABLE public.tempa FROM postgres;
GRANT ALL ON TABLE public.tempa TO postgres;
GRANT SELECT ON TABLE public.tempa TO postgres;


--
-- Name: TABLE tempcustomer; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.tempcustomer FROM PUBLIC;
REVOKE ALL ON TABLE public.tempcustomer FROM postgres;
GRANT ALL ON TABLE public.tempcustomer TO postgres;
GRANT SELECT ON TABLE public.tempcustomer TO postgres;


--
-- Name: TABLE temphi; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.temphi FROM PUBLIC;
REVOKE ALL ON TABLE public.temphi FROM postgres;
GRANT ALL ON TABLE public.temphi TO postgres;
GRANT SELECT ON TABLE public.temphi TO postgres;


--
-- Name: TABLE tempp; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.tempp FROM PUBLIC;
REVOKE ALL ON TABLE public.tempp FROM postgres;
GRANT ALL ON TABLE public.tempp TO postgres;
GRANT SELECT ON TABLE public.tempp TO postgres;


--
-- Name: TABLE tempp11; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.tempp11 FROM PUBLIC;
REVOKE ALL ON TABLE public.tempp11 FROM postgres;
GRANT ALL ON TABLE public.tempp11 TO postgres;
GRANT SELECT ON TABLE public.tempp11 TO postgres;


--
-- Name: TABLE tempsalesman; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.tempsalesman FROM PUBLIC;
REVOKE ALL ON TABLE public.tempsalesman FROM postgres;
GRANT ALL ON TABLE public.tempsalesman TO postgres;
GRANT SELECT ON TABLE public.tempsalesman TO postgres;


--
-- Name: TABLE testtable; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.testtable FROM PUBLIC;
REVOKE ALL ON TABLE public.testtable FROM postgres;
GRANT ALL ON TABLE public.testtable TO postgres;
GRANT SELECT ON TABLE public.testtable TO postgres;


--
-- Name: TABLE testtesing; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.testtesing FROM PUBLIC;
REVOKE ALL ON TABLE public.testtesing FROM postgres;
GRANT ALL ON TABLE public.testtesing TO postgres;
GRANT SELECT ON TABLE public.testtesing TO postgres;


--
-- Name: TABLE testtest; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.testtest FROM PUBLIC;
REVOKE ALL ON TABLE public.testtest FROM postgres;
GRANT ALL ON TABLE public.testtest TO postgres;
GRANT SELECT ON TABLE public.testtest TO postgres;


--
-- Name: TABLE trained_in; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.trained_in FROM PUBLIC;
REVOKE ALL ON TABLE public.trained_in FROM postgres;
GRANT ALL ON TABLE public.trained_in TO postgres;
GRANT SELECT ON TABLE public.trained_in TO postgres;


--
-- Name: TABLE trenta; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.trenta FROM PUBLIC;
REVOKE ALL ON TABLE public.trenta FROM postgres;
GRANT ALL ON TABLE public.trenta TO postgres;
GRANT SELECT ON TABLE public.trenta TO postgres;


--
-- Name: TABLE undergoes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.undergoes FROM PUBLIC;
REVOKE ALL ON TABLE public.undergoes FROM postgres;
GRANT ALL ON TABLE public.undergoes TO postgres;
GRANT SELECT ON TABLE public.undergoes TO postgres;


--
-- Name: TABLE v1; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.v1 FROM PUBLIC;
REVOKE ALL ON TABLE public.v1 FROM postgres;
GRANT ALL ON TABLE public.v1 TO postgres;
GRANT SELECT ON TABLE public.v1 TO postgres;


--
-- Name: TABLE view; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.view FROM PUBLIC;
REVOKE ALL ON TABLE public.view FROM postgres;
GRANT ALL ON TABLE public.view TO postgres;
GRANT SELECT ON TABLE public.view TO postgres;


--
-- Name: TABLE vowl; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.vowl FROM PUBLIC;
REVOKE ALL ON TABLE public.vowl FROM postgres;
GRANT ALL ON TABLE public.vowl TO postgres;
GRANT SELECT ON TABLE public.vowl TO postgres;


--
-- Name: TABLE zebras; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE public.zebras FROM PUBLIC;
REVOKE ALL ON TABLE public.zebras FROM postgres;
GRANT ALL ON TABLE public.zebras TO postgres;
GRANT SELECT ON TABLE public.zebras TO postgres;


--
-- PostgreSQL database dump complete
--

