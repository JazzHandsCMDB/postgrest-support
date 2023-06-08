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
-- Sets up all the database structures for a new endpoint
--
CREATE OR REPLACE FUNCTION postgrest_support.configure_endpoint(
	service_Id	INTEGER,
	schema		TEXT
) RETURNS BOOLEAN
AS $$
DECLARE
	_svc		jazzhands.service%ROWTYPE;
	svc_name	TEXT;
	user_role	TEXT;
	assm_role	TEXT;
	_t			TEXT;
	default_atn	TEXT;
	default_aur	TEXT;
BEGIN

	SELECT property_value_json->>'default_authenticator',
		property_value_json->>'default_all_users_role'
		INTO default_atn, default_aur
		FROM property
		WHERE property_type = 'Defaults'
		AND property_name = 'postgrest_support';


	SELECT * INTO _svc FROM service s WHERE s.service_id =
		configure_endpoint.service_id;

	svc_name := regexp_replace(_svc.service_name, '-', '_', 'g');

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Unknown Service id %', service_id;
	END IF;

	--
	-- The user role is granted to every user who can access the API so that
	-- grant son obejects work.  The login user is granted to assumable
	-- role in order for postgrest to become the user.

	user_role := format('%s_postgrest_users', svc_name);
	assm_role := format('%s_postgrest_assumable_role', svc_name);

	PERFORM * FROM pg_roles WHERE rolname IN (user_role, assm_role);
	IF FOUND THEN
		RAISE EXCEPTION 'Roles exist for user';
	END IF;

	EXECUTE format('CREATE ROLE %s NOLOGIN', user_role);
	EXECUTE format('CREATE ROLE %s NOINHERIT NOLOGIN', assm_role);

	EXECUTE format(
		'GRANT %s to %s',
			coalesce(default_aur, 'all_postgrest_users'),
			user_role
	);


	EXECUTE format(
		'GRANT USAGE ON SCHEMA %s TO %s', schema, user_role
	);


	EXECUTE format(
		'GRANT %s TO %s', assm_role, coalesce(default_atn, 'pgr_atr')
	);

	RETURN true;
END;
$$
SET search_path = jazzhands
LANGUAGE plpgsql SECURITY INVOKER;
