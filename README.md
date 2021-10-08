# PostgREST Support

This module provides all the components to setup an endpoint and manage
various ways for users to login to execute api calls with
[PostgREST](https://postgrest.org/).

It requires database users and JazzHands accounts be tied together via some
mechanism (a feed of some sort) .   Conveniently, it also provides a mechanism
for doing that under certain conditions.

The general interface is kind of klunky and probably needs a PostgREST
interface to make better.  That would lead to a chicken/egg thing...

Although not strictly, true, practically, [jazzhands-openid(https://github.com/JazzHandsCMDB/jazzhands-openid) is required for database structures.   It is
also a good JWT issuing platform.   It is possible to use other things instead
of in addition to that to issue JWTs.

## TL;DR - Installation

This is the bare minimum to get things up and working.

An installation of [minter](https://github.com/JazzHandsCMDB/jazzhands-openid) needs to exist for the quick-and-dirty installation.  As with that, this installs inside a different schema in the same database as a [JazzHands](https://github.com/JazzHandsCMDB/) and [JazzHands OpenID](https://github.com/JazzHandsCMDB/jazzhands-openid) installation.

### Database Configuration

1. A user to be used as the `postgrest_api_authenticator` needs to exist.  The default is pgr_atr (to make audit log entries shorter) but it is possible to override this.  (The all_app_users group is site-specific and may be able to be left off).
```
	CREATE ROLE pgr_atr IN GROUP all_app_users;
```
2. Create the database and give appropriate grants.  This can be run as the postgres superuser, and it will lower and raise permissions as needed, or the script can be dissected with various parts run by various users
```
	\ir database/create_all.sql
```
3. In all likelihood, an account collection to capture all the roles should be created.  This is an implementation decision, but a smart one.
```
INSERT INTO val_account_collection_type (
        account_collection_type, description
) VALUES (
        'postgrest-support', 'nuff said'
);
```

### Setup a service endpoint

At this point, the database is ready to have postgrest things available.  Here
are the basic steps to get things up and running.

It is recommended that the the api be given a name and a version so that
it is possible to do breaking changes in the future and transition to
new iterations of the api without having to launch a new server.  It
is not recommended that a new version be issues for every change.
Typically this means that a schema would be named service_api_v1 for a
"service-api" endpoint and v1 for the first version, and then mappings in
nginx or similar can be used to direct traffic to the right place.

It is also recommended to only grant access to one schema per api
endpoint and maintain all the interfaces there.  Access to raw base tables
is discouraged because it makes it harder to adjust them over time.

IT is likely that there should be api endpoints for many of these things.

#### Configure a Service

1. Add the service to the database as described in the 
[jazzhands-openid(https://github.com/JazzHandsCMDB/jazzhands-openid) documentation.   These directions will assume that `testinator-api` is the name of the service that was created, as in those docs.
2.  Create a schema for the api endpoint:
```
	create schema testinator_api_v1;
```

3. If desired, create an account collection for Kerberos logins for the API.  In this example, it will be `postgrest-support:testinator-api-negotiate` and managed users will be setup with the `pgrst_` prefix and will get a default lifetime of 43200 seconds:
```
WITH ac AS (
        INSERT INTO account_collection (
                account_collection_name, account_collection_type
        ) VALUES (
                'testinator-api-negotiate', 'postgrest-support'
        ) RETURNING *
) INSERT INTO property (
        property_type, property_name, service_version_collection_id,
        account_collection_id, property_value_json
) SELECT 'jazzhands-openid', 'authentication-rules', service_version_collection_id,
        account_collection_id, '{"method":"negotiate", "prefix": "pgrst_", "max_token_lifetime": 43200 }'
FROM ac, service_version_collection
WHERE service_version_collection_name = 'testinator-api'
AND service_version_collection_type = 'current-services';
;
```

4. If desired, create an account collection for password logins for the API.  In this example, it will be `postgrest-support:testinator-api-password` and managed users will be setup with the `pgrst_` prefix and will get a default lifetime of 43200 seconds:
```
WITH ac AS (
        INSERT INTO account_collection (
                account_collection_name, account_collection_type
        ) VALUES (
                'testinator-api-password', 'postgrest-support'
        ) RETURNING *
) INSERT INTO property (
        property_type, property_name, service_version_collection_id,
        account_collection_id, property_value_json
) SELECT 'jazzhands-openid', 'authentication-rules', service_version_collection_id,
        account_collection_id, '{"method":"password", "prefix": "pgrst_", "max_token_lifetime": 43200 }'
FROM ac, service_version_collection
WHERE service_version_collection_name = 'testinator-api'
AND service_version_collection_type = 'current-services';
;
```

5. Add people to those two account collections (via the `account_collection_hier` and `account_collection_account` tables.

6. Setup all the roles and various bits for the service.  This will create two roles, testinator_api_postgrest_assumable_role and testinator_api_postgrest_users.  The former has users that use the api granted to it and the second has all the users that use the api put in it.
```
SELECT service_name,
        postgrest_support.configure_endpoint(service_id, 'testinator_api_v1')
FROM jazzhands.service
WHERE service_name = 'testinator-api'
AND service_type = 'network';
```

7. Populate the schema with things.

8. grant api access to the underling tables in the schema:
```
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA
        testinator_api_v1 TO testinator_api_postgrest_users;
```

9. Make all the users appear and grant them properly:
```
	SELECT postgrest_support.synchronize_postgrest_roles();
```

10. Make the previous step appear in a cron job for regular syncing.

11. Grant permissions to users:
```
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA
        testinator_api_v1 TO testinator_api_postgrest_users;
```

XXX permsisions and alternate roles

#### Device Authentication

If desired, a device collection can be setup with devices that are allowed to authenticate (via Kerberos, at this time).  This example has "everything assigned to an mclass":
```
INSERT INTO property (
        property_type, property_name, service_version_collection_id,
        device_collection_id, property_value_json
) SELECT 'jazzhands-openid', 'permit-device-authentication', service_version_collection_id,
        device_collection_id, '{"role": "postgrest_device_role", "max_token_lifetime": 900 }'
FROM device_collection, service_version_collection
WHERE service_version_collection_name = 'testinator-api'
AND service_version_collection_type = 'current-services'
AND device_collection_type = 'by-coll-type'
AND device_collection_name = 'mclass'
;
```
### PostgREST Configuration

Typically, there are two endpoints per datacenter, one for read and one for
write.  This allows load to be split out.  Each is a docker configuration.

Nginx (or similar) will proxy traffic into the right instance based on the
incoming URL.

#### Docker Configuration

For docker.  The contents of `/etc/postgrest/postgrest.jwk.pub` can be
gotten with the signkeymgr script that's packed with [jazzhands-openid](https://github.com/JazzHandsCMDB/jazzhands-openid), but the gist is to run:

```
# signkeymgr export --service testinator-api --jwk
```

That output is put directly in the file, or as part of an array in the file
that shows up inside the container as `/etc/postgrest/postgrest.jwk.pub`,
which is also how you rotate certs in a backwards compatible way. (any JWK
in the file or in an array in the file is trusted).

You will also need the outside name of the web endpoint and the audience/scope
that the JWT presented will have (that's the service endpoint using
[minter](https://github.com/JazzHandsCMDB/jazzhands-openid)

A docker compose file that works is:

```
---
version: "3.7"

services:
  postgrest_testinator:
    image: postgrest/postgrest:v10.2.0
    ports:
      - "34107:3000"
    environment:
      PGRST_DB_URI: postgres://pgr_atr:password@cmdb.example.com:5432/cmdb
      PGRST_DB_SCHEMA:  testinator_api_v1
      PGRST_DB_ANON_ROLE: ''
      PGRST_JWT_SECRET: '@/etc/postgrest/postgrest.jwk.pub'
      PGRST_JWT_AUD: 'https://api.example.com/testinator/v1'
      PGRST_SERVER_PROXY_URI: 'https://api.example.com/'
      PGRST_SERVER_PORT: 3000
      PGRST_PRE_REQUEST: "postgrest_support.pre_request"
      PGRST_USE_LEGACY_GUCS: true
      PGRST_LOG_LEVEL: info
    volumes:
      - ./postgrest.jwk.pub:/etc/postgrest/postgrest.jwk.pub
```

#### Nginx config

The interesting part of an nginx configuration would be:

```
http {
	... 
	upstream testinator_v1_DELETE {
		server     127.0.0.1:34107  fail_timeout=10s;
	}
	upstream testinator_v1_GET {
		server     127.0.0.1:34107  fail_timeout=10s;
	}
	upstream testinator_v1_PATCH {
		server     127.0.0.1:34107  fail_timeout=10s;
	}
	upstream testinator_v1_POST {
		server     127.0.0.1:34107  fail_timeout=10s;
	}

	location ~ /testinator/v1(?:/(.*))?$ {
		proxy_pass            http://testinator_v1_$request_method/$1$is_args$args;
		proxy_read_timeout    90s;
		proxy_connect_timeout 90s;
		proxy_send_timeout    90s;
		proxy_set_header      Host $host;
		proxy_set_header      X-Real-IP $remote_addr;
		proxy_set_header      X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header      Proxy "";
	}

}
```

## PostgreSQL and JazzHands best practices

### How PostgREST works

PostgREST provides a restfulish web api interface that directly maps to
underlying database schema (tables, views, stored procedures) that a user
has access to to restfulish endpoints.    It uses the PostgreSQL `SET LOCAL
ROLE` command to assume the identity of a user, so runs with whatever
permissions that database user has.  It uses a Bearer token (encoded JWT)
to authenticate the user, and those are signed by a trusted public key (or
a number of other options).   Authorization is done by the database and the
database knows both the user the role has been set to (for low level authz)
and the contents of the JWT are exposed if there is a need to do more intimate
parsing of the user.

JWT and thus, PostgREST have the concept of "audiences" which are lists of areas
where a given JWT can be used.   In this implementation, the audiences are
the base URL of the service of the web site (https://myapi.example.com/api/v1/).

### JazzHands Integration

JWTs can be issued by the openid connect minter, and most of the integration
is written with that in mind, although it is not strictly necessary.

Although it is possible to expose the base JazzHands tables (or any tables)
via this interface, it is probably more desirable to provide views and stored
procedures (or INSTEAD OF triggers on views) that do all the work to make it
easier to evolve the schema.

Unfortunately, that does prevent the use of row level authorization
because that only works in PostgreSQL on tables.  Instead, cleverness in
view definition and access control directly in triggers is required to
do granular permissions.

This is just a convention, but it is recommended that the schema be
named api_vX where X is a number and the nginx interface translates
this to api/vX (so https://api.example.com/api/v1/ would map to the
schema api_vX).  This is just future proofing so two incompatible
versions of an api could exist and a transition could take place.  It is
_not_ recommended that new versions get issued for every change, just
ones that are deemed very incompatible.  Ideally, old interfaces are
slowly deprecated within a given schema over time and the old version goes
away.

That said, sometimes a new version is appropriate.

## PostgREST-Support Components

PostgREST uses a bearer token that is really a base64 encoded signed JWT
to authenticate users.  The JWT contains various pieces about the user
that will be used underneath and tells how to authenticate as the user.

There's very little code in all of this.  Most of it is JWT management
and conventions.

### database schema

This leans heavily on the views inside [jazzhands-openid(https://github.com/JazzHandsCMDB/jazzhands-openid).  Otherwise, it exposes a handful of views to make
managing users and access easier and they are primarily used by the
`postgrest_support.synchronize_postgrest_roles()` function.  These are as
follows:

* **authorized_users** - users that are authorized to use various api endpoints, including the roles they should be part of
* **unauthorized_users** - roles who are in the previous roles enumerated in the **authorized_users** view, which should have access revoked.
* **missing_users** - users who should be in the rules in **authorized_users** but are not.
* **unused_mapped_users** - users that match the prefix/suffix regular expressions defined in `jazzhands_openid` that should be dropped.  Non-mapped users would not be included.

## Database Configuration

There are some helper stored procedures for setting the API up _and they
should be used_.  In the future, they will be extended as more of the
roles and pieces are modeled in the account table, but not yet.

This implementation depends on certain service model to exist for the api.
This may be inside another service.   Each service uses a private key to
sign JWTs that are scoped to the API.  It is possible for services to share the
key and for one JWT to handle multiple scopes/audiences although minter
does not support this at this time.

jazzhands-openid mentions jazzhands database structures that that need to be created.

To setup an endpoint (this is also described in the TL:DR installation
section above:
```
SELECT service_name,
        postgrest_support.configure_endpoint(service_id, 'schema_name')
FROM jazzhands.service
WHERE service_name = 'service_name'
AND service_type = 'network';
```

After that, the following:

* A schema for all the objects
* If necessary, a role for device access (may be shared across instances)

Once configured, grants need to be setup to the previously created views with
something like:
* GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA apiname_api_v1 TO testinator_api_postgrest_users;
* GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA testinator_api_v1 TO apiname_api_postgrest_users;

All other grants are managed by
`postgrest_support.synchronize_postgrest_roles()` which will need to be
called on any change to usage of who can talk to the API.   This probably
wants to be called as part of a feed and possibly from triggers on changes
to account_collections.  This will come in a future iteration.

If a permissions is granted to a user via `GRANT`, then they'll be immediate.
This probably all needs to be reconciled.

