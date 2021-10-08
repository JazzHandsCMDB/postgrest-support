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
-- Does any validation of the JWT.   Since JWTs are short lived, this just
-- does nothing but it is setup in case that needs to be added in later.
-- 
CREATE OR REPLACE FUNCTION postgrest_support.pre_request() RETURNS VOID
AS $$
BEGIN
    -- could check to see if users is still active, but the limited life of
    -- the JWT should be enough.  Could also check for expired JWT.  have
    -- this function at all, just in case...
    RETURN;
END;
$$
SET search_path = postgrest_support
LANGUAGE plpgsql SECURITY DEFINER;
