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
-- This is the basis for which users can access which services.
--
CREATE OR REPLACE VIEW postgrest_support.authorized_users AS
SELECT
	service_id, service_name, service_endpoint_uri, 
	translated_login AS assumable_username,	-- XXX
	format('%s_postgrest_users', role_base) AS service_user_role,
	format('%s_postgrest_assumable_role', role_base) AS service_assumable_role,
	mapped_user
FROM (
	SELECT  *,
			regexp_replace(svc.service_name, '-', '_', 'g') AS role_base
	FROM (
		SELECT service_id, service_endpoint_uri, translated_login,
				translated_login != login AS mapped_user
			FROM jazzhands_openid.authentication_rules
		UNION
		SELECT service_id, service_endpoint_uri, translated_actas,
				translated_actas != actas
			FROM jazzhands_openid.permitted_account_impersonation
		UNION
		SELECT DISTINCT service_id, service_endpoint_uri, 
				device_role AS translated_login,
				true::boolean AS mapped_user
			FROM jazzhands_openid.service_device_permitted_authentication
	) i
	JOIN jazzhands.service svc USING (service_id)
) base
;
