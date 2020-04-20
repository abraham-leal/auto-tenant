# auto-tenant
Automatically create "tenant" resources in Confluent Cloud

Tenant resources include:
- A service account
- An API Key and Secret Pair
- A set of topics the "tenant" will use. Sourced from the given file
- ACLs for reading and writing to topics specified in the topics file
- ACLs for reading consumer groups named the same as the topic created

Changelog from base:
- Add custom partitioning for topics created
-- Note: The topics file must follow the format topic=partitions per line, "=" being the recognized separator (so do not name topics with a "=" in them). If no partition is set ("topic") the default of 6 partitions is applied.
- Add Read permissions on consumer groups named equal to the topics created
- Delete associated API key/secret pairs when deleting tenants

NOTE: No unit tests have been written for features in changelog from base. Testing has happened locally.

This is provided as is. No professional support is given.
