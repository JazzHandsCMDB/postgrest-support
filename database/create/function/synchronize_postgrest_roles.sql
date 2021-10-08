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
-- Looks through what can login to services and make sure that the users
-- exist and are in the right group, and remove if they should not be.
--
-- This makes assumptions about role names compared to the services, and
-- there's a lot of room for making this less magical.
--
-- XXX: in all liklihood, the queries here should be wrapped into views
-- so the complexity is not here.
--
-- This will spew about grants already existing if they do.
--
CREATE OR REPLACE FUNCTION postgrest_support.synchronize_postgrest_roles(
) RETURNS BOOLEAN
AS $$
DECLARE
	_r		RECORD;
	_seen	TEXT[];
BEGIN
	--
	-- Add users that are supposed to be there that are not
	--
	FOR _r IN SELECT * FROM missing_users
	LOOP
		IF NOT _r.service_user_role_exists
			OR NOT _r.service_assumable_role_exists
		THEN
			RAISE DEBUG 'Skipping %', to_json(_r);
			continue;
		END IF;

		IF _r.needs_role AND (_seen IS NULL OR NOT _r.assumable_username = ANY(_seen) ) THEN
			EXECUTE format('CREATE ROLE %s NOLOGIN', _r.assumable_username);
			RAISE DEBUG 'Creating user %', _r.assumable_username;
			IF _seen IS NULL THEN
				_seen := ARRAY[_r.assumable_username];
			ELSE
				_seen := _seen || _r.assumable_username;
			END IF;
		END IF;
		IF _r.needs_service_user_role THEN
			EXECUTE format('GRANT %s TO %s', _r.service_user_role, _r.assumable_username);
			RAISE DEBUG 'Granting % to % ', _r.service_user_role,_r.assumable_username;
		END IF;
		IF _r.needs_assumable_role THEN
			EXECUTE format('GRANT %s TO %s', _r.assumable_username, _r.service_assumable_role);
			RAISE DEBUG 'Granting % to % ', _r.assumable_username, _r.service_assumable_role;
		END IF;
	END LOOP;

	--
	-- now remove users that are not suppsoed to be there.
	--
	FOR _r IN SELECT * FROM unauthorized_users
	LOOP
		IF _r.service_assumable_role IS NOT NULL THEN
			EXECUTE format('REVOKE %s FROM %s', _r.assumable_username, _r.service_assumable_role);
			RAISE DEBUG 'Revoking % from %', _r.assumable_username, _r.service_assumable_role;
		END IF;
		IF _r.service_user_role IS NOT NULL THEN
			EXECUTE format('REVOKE %s FROM %s', _r.service_user_role, _r.assumable_username);
			RAISE DEBUG 'Revoking % from %', _r.service_user_role, _r.assumable_username;
		END IF;
	END LOOP;

	--
	-- meh; drop all the users that match the patterns but do not go after
	-- users that show up withoiut a prefix/suffix
	FOR _r IN SELECT * FROM unused_mapped_users
	LOOP
		EXECUTE format('DROP USER %s', _r.rolname);
		RAISE DEBUG 'Dropping user %', _r.rolname;
	END LOOP;
	RETURN true;
END;
$$
SET search_path = postgrest_support, pg_catalog
LANGUAGE plpgsql SECURITY INVOKER;
