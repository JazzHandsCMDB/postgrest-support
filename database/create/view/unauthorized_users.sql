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
-- Users in the managed views that should not be there. 
--

CREATE OR REPLACE VIEW postgrest_support.unauthorized_users AS
WITH asm AS NOT MATERIALIZED (
		SELECT 
			rhs.rolname AS assumable_username,
			lhs.rolname AS service_assumable_role
		FROM pg_auth_members p
		JOIN pg_roles lhs on p.member = lhs.oid
		JOIN pg_roles rhs ON p.roleid = rhs.oid
		WHERE lhs.rolname IN (
			SELECT service_assumable_role
			FROM authorized_users
		) AND (lhs.rolname, rhs.rolname) NOT IN (
			SELECT service_assumable_role, assumable_username
			FROM authorized_users
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
			FROM authorized_users
		) AND (rhs.rolname, lhs.rolname) NOT IN (
			SELECT service_user_role, assumable_username
			FROM authorized_users
		)
), x(assumable_username, service_user_role, service_assumable_role) AS NOT MATERIALIZED (
	SELECT assumable_username, NULL, service_assumable_role FROM asm 
	UNION 
	SELECT assumable_username, service_user_role, NULL FROM svc 
) SELECT x.*
FROM x
;

