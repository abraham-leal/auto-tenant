# auto-tenant
Automatically create "tenant" resources in Confluent Cloud

Changelog from base:
- Add custom partitioning for topics created
-- Note: The topics file must follow the format topic=partitions per line, "=" being the recognized separator (so do not name topics with a "=" in them). If no partition is set ("topic") the default of 6 partitions is applied.
- Add Read permissions on consumer groups named equal to the topics created
- Delete associated API key/secret pairs when deleting tenants

NOTE: No unit tests have been written for features in changelog from base. Testing has happened locally.

This is provided as is. No professional support is given.
