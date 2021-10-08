--
-- Copyright (c) 2023 Todd Kover
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
-- Users that match mapping rules that are not assigned to any services.
--
CREATE OR REPLACE VIEW postgrest_support.unused_mapped_users AS
SELECT DISTINCT rolname
FROM pg_roles
	JOIN jazzhands_openid.mapped_user_regular_expressions pattern
	ON rolname ~ pattern.r
WHERE rolname NOT IN (
	SELECT assumable_username
	FROM authorized_users
)
;

