# auto-tenant
Automatically create "tenant" resources in Confluent Cloud

Changelog from base:
- Add Read permissions on consumer groups named equal to the topics created
- Delete associated API key/secret pairs when deleting tenants

TODO:
- Add custom partitioning for topics created
