--
-- Copyright (c) 2021-2023 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--
--
-- This is meant to be rerun if nothing changes.  It won't destroy anything.
--
-- runs as postgres (superuser, really)
--
\set ON_ERROR_STOP

DO $$
BEGIN
	CREATE USER postgrest_support IN GROUP schema_owners;
	RAISE NOTICE 'created postgrest_support';
EXCEPTION WHEN duplicate_object THEN
	RAISE NOTICE 'postgrest_support already exists, skipping create';
END;
$$;

ALTER USER postgrest_support SET search_path=postgrest_support;

GRANT EXECUTE ON FUNCTION jazzhands.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb) TO postgrest_support;

DO $$
DECLARE
        _tal INTEGER;
BEGIN
        select count(*)
        from pg_catalog.pg_namespace
        into _tal
        where nspname = 'postgrest_support';
        IF _tal = 0 THEN
                DROP SCHEMA IF EXISTS postgrest_support;
                CREATE SCHEMA postgrest_support AUTHORIZATION postgrest_support;
                COMMENT ON SCHEMA postgrest_support IS 'jazzhands stuff';

        END IF;
END;
$$;

GRANT pgcrypto_roles TO postgrest_support;
GRANT USAGE ON schema jazzhands_openid TO postgrest_support;
GRANT SELECT ON jazzhands_openid.authentication_rules TO postgrest_support;
GRANT SELECT ON jazzhands_openid.service_device_permitted_authentication TO postgrest_support;
GRANT SELECT ON jazzhands_openid.permitted_account_impersonation TO postgrest_support;
GRANT SELECT ON jazzhands_openid.mapped_user_regular_expressions TO postgrest_support;

GRANT USAGE ON schema jazzhands TO postgrest_support;
GRANT SELECT ON jazzhands.service TO postgrest_support;

INSERT INTO jazzhands.val_property  (
	property_type, property_name, property_data_type,
	property_value_json_schema
 ) VALUES (
	'Defaults', 'postgrest_support', 'json',
	'{
		"type": "object",
		"title": "PostgREST Support Configuration",
		"$schema": "http://json-schema.org/draft-06/schema#",
		"required": [
			"method"
		],
		"properties": {
			"default_authenticator": {
				"type": "string"
			},
			"default_all_users_role": {
				"type": "string"
			}
		},
	"description": "configuration (changes from default) for postgrest_support"
	}'
);
