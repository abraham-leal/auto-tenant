# auto-tenant
Automatically create "tenant" resources in Confluent Cloud

Changelog from base:
- Add custom partitioning for topics created
-- Note: The topics file must follow the format topic=partitions per line, "=" being the recognized separator (so do not name topics with a "=" in them). If no partition is set ("topic") the default of 6 partitions is applied.
- Add Read permissions on consumer groups named equal to the topics created
- Delete associated API key/secret pairs when deleting tenants

Update (05/26/2020):
- The deletion script now limits deletion to a specific service account's resources
- Deletion of topics is now confirmed before proceeding, given its a dangerous operation
- Creation and deletion of tenant now issues prefixed CG ACLs commands
- Output is more readable for both creation and deletion


NOTE: No unit tests have been written for features in changelog from base. Testing has happened locally.

This is provided as is. No professional support is given.
