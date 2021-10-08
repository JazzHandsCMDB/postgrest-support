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
-- Users which to be created or roles granted.  This will cleanup partial
-- creations.
--
CREATE OR REPLACE VIEW postgrest_support.missing_users AS
WITH asm AS NOT MATERIALIZED (
		SELECT 
			rhs.rolname AS assumable_username,
			lhs.rolname AS service_assumable_role
		FROM pg_auth_members p
		JOIN pg_roles lhs on p.member = lhs.oid
		JOIN pg_roles rhs ON p.roleid = rhs.oid
		WHERE lhs.rolname IN (
			SELECT service_assumable_role
			FROM postgrest_support.authorized_users
		)
), svc AS NOT MATERIALIZED (
		SELECT 
			lhs.rolname AS assumable_username,
			rhs.rolname AS service_user_role
		FROM pg_auth_members p
		JOIN pg_roles lhs on p.member = lhs.oid
		JOIN pg_roles rhs ON p.roleid = rhs.oid
		WHERE rhs.rolname IN (
			SELECT service_user_role
			FROM postgrest_support.authorized_users
		)
) SELECT sub.*,
	su.oid IS NOT NULL AS service_user_role_exists,
	sa.oid IS NOT NULL AS service_assumable_role_exists
FROM (
	SELECT p.*,
		r.oid IS NULL AS needs_role,
		asm.assumable_username IS NULL AS needs_assumable_role,
		svc.assumable_username IS NULL AS needs_service_user_role
	FROM authorized_users p
		LEFT JOIN pg_roles r ON r.rolname = p.assumable_username
		LEFT JOIN asm USING (assumable_username, service_assumable_role)
		LEFT JOIN svc USING (assumable_username, service_user_role)
) sub 
	LEFT JOIN pg_roles su ON su.rolname = sub.service_user_role
	LEFT JOIN pg_roles sa ON sa.rolname = sub.service_assumable_role
WHERE needs_role 
OR needs_assumable_role 
OR needs_service_user_role;
