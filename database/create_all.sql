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
-- This is what was used to create everything from scratch the very 
-- first time.
--

\set ON_ERROR_STOP
\pset pager off

\ir create_scaffolding.sql

SAVEPOINT scaffolding;

set role postgrest_support;
set search_path=postgrest_support;
\ir create/ddl.sql

RESET role;

CREATE ROLE pgr_atr;
CREATE ROLE all_postgrest_users NOLOGIN;

GRANT USAGE ON SCHEMA postgrest_support TO all_postgrest_users;
GRANT EXECUTE ON FUNCTION postgrest_support.pre_request() TO all_postgrest_users;

SAVEPOINT ddl;
